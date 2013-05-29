RSpec::Matchers.define :invalidate do
  match do |actual|
    actual.save.should == false
    actual.errors[:base].should == ["Access denied"]
  end
end

RSpec::Matchers.define :validate do
  match do |actual|
    actual.class.transaction do
      actual.save.should == true
      raise ActiveRecord::Rollback
    end

    true
  end
end

def log!
  around(:each) do |e|
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    e.run
    ActiveRecord::Base.logger = nil
  end
end