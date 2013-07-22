RSpec::Matchers.define :invalidate do
  match do |actual|
    actual.save.should == false
    actual.errors[:base].should == ["Access denied"]
  end
end

RSpec::Matchers.define :validate do
  match do |actual|
    actual.save.should == true

    true
  end
end

RSpec::Matchers.define :destroy do
  match do |actual|
    actual.destroy.should == actual

    actual.class.where(id: actual.id).delete_all

    true
  end
end

RSpec::Matchers.define :survive do
  match do |actual|
    actual.destroy.should == false

    actual.class.where(id: actual.id).delete_all

    true
  end
end

def log!
  around(:each) do |e|
    Mongoid.logger = Logger.new(STDOUT)
    e.run
    Mongoid.logger = nil
  end
end

def assign!(model, fields)
  model.assign_attributes(fields)
end

def read_attribute(model, field)
  model.read_attribute(field)
end