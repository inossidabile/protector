RSpec::Matchers.define :invalidate do
  match do |actual|
    actual.save.should == false
    actual.errors[:base][0].starts_with?("Access denied to").should == true
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

RSpec::Matchers.define :destroy do
  match do |actual|
    actual.class.transaction do
      actual.destroy.should == actual
      raise ActiveRecord::Rollback
    end

    actual.class.where(id: actual.id).delete_all

    true
  end
end

RSpec::Matchers.define :survive do
  match do |actual|
    actual.class.transaction do
      actual.destroy.should == false
      raise ActiveRecord::Rollback
    end

    actual.class.where(id: actual.id).delete_all

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

def assign!(model, fields)
  model.assign_attributes(fields)
end

def read_attribute(model, field)
  model.read_attribute(field)
end