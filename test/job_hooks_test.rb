require File.dirname(__FILE__) + '/test_helper'

module PerformJob
  def perform_job(klass, *args)
    resque_job = Resque::Job.new(:testqueue, 'class' => klass, 'args' => args)
    resque_job.perform
  end
end

context "Resque::Job before_perform" do
  include PerformJob

  class BeforePerformJob
    def self.before_perform(history)
      history << :before_perform
    end
    def self.perform(history)
      history << :perform
    end
  end

  test "it runs before_perform before perform" do
    result = perform_job(BeforePerformJob, history=[])
    assert_equal true, result, "perform returned true"
    assert_equal history, [:before_perform, :perform]
  end

  class BeforePerformJobFails
    def self.before_perform(history)
      history << :before_perform
      raise StandardError
    end
    def self.perform(history)
      history << :perform
    end
  end

  test "raises an error and does not perform if before_perform fails" do
    history = []
    assert_raises StandardError do
      perform_job(BeforePerformJobFails, history)
    end
    assert_equal history, [:before_perform], "Only before_perform was run"
  end

  class BeforePerformJobAborts
    def self.before_perform(history)
      history << :before_perform
      raise Resque::Job::DontPerform
    end
    def self.perform(history)
      history << :perform
    end
  end

  test "does not perform if before_perform raises Resque::Job::DontPerform" do
    result = perform_job(BeforePerformJobAborts, history=[])
    assert_equal false, result, "perform returned false"
    assert_equal history, [:before_perform], "Only before_perform was run"
  end
end

context "Resque::Job after_perform" do
  include PerformJob

  class AfterPerformJob
    def self.perform(history)
      history << :perform
    end
    def self.after_perform(history)
      history << :after_perform
    end
  end

  test "it runs after_perform after perform" do
    result = perform_job(AfterPerformJob, history=[])
    assert_equal true, result, "perform returned true"
    assert_equal history, [:perform, :after_perform]
  end

  class AfterPerformJobFails
    def self.perform(history)
      history << :perform
    end
    def self.after_perform(history)
      history << :after_perform
      raise StandardError
    end
  end

  test "raises an error but has already performed if after_perform fails" do
    history = []
    assert_raises StandardError do
      perform_job(AfterPerformJobFails, history)
    end
    assert_equal history, [:perform, :after_perform], "Only after_perform was run"
  end
end

context "Resque::Job around_perform" do
  include PerformJob

  class AroundPerformJob
    def self.perform(history)
      history << :perform
    end
    def self.around_perform(history)
      history << :start_around_perform
      yield
      history << :finish_around_perform
    end
  end

  test "it runs around_perform then yields in order to perform" do
    result = perform_job(AroundPerformJob, history=[])
    assert_equal true, result, "perform returned true"
    assert_equal history, [:start_around_perform, :perform, :finish_around_perform]
  end

  class AroundPerformJobFailsBeforePerforming
    def self.perform(history)
      history << :perform
    end
    def self.around_perform(history)
      history << :start_around_perform
      raise StandardError
      yield
      history << :finish_around_perform
    end
  end

  test "raises an error and does not perform if around_perform fails before yielding" do
    history = []
    assert_raises StandardError do
      perform_job(AroundPerformJobFailsBeforePerforming, history)
    end
    assert_equal history, [:start_around_perform], "Only part of around_perform was run"
  end

  class AroundPerformJobFailsWhilePerforming
    def self.perform(history)
      history << :perform
      raise StandardError
    end
    def self.around_perform(history)
      history << :start_around_perform
      begin
        yield
      ensure
        history << :ensure_around_perform
      end
      history << :finish_around_perform
    end
  end

  test "raises an error but may handle exceptions if perform fails" do
    history = []
    assert_raises StandardError do
      perform_job(AroundPerformJobFailsWhilePerforming, history)
    end
    assert_equal history, [:start_around_perform, :perform, :ensure_around_perform], "Only part of around_perform was run"
  end

  class AroundPerformJobDoesNotHaveToYield
    def self.perform(history)
      history << :perform
    end
    def self.around_perform(history)
      history << :start_around_perform
      history << :finish_around_perform
    end
  end

  test "around_perform is not required to yield" do
    history = []
    result = perform_job(AroundPerformJobDoesNotHaveToYield, history)
    assert_equal false, result, "perform returns false"
    assert_equal history, [:start_around_perform, :finish_around_perform], "perform was not run"
  end
end
