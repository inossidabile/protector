RSpec::Matchers.define :invalidate do
  match do |actual|
    DB.transaction do
      expect{ actual.save }.to raise_error
      actual.errors.on(:base)[0].starts_with?("Access denied to").should == true
      raise Sequel::Rollback
    end

    true
  end
end

RSpec::Matchers.define :validate do
  match do |actual|
    DB.transaction do
      expect{ actual.save }.to_not raise_error
      raise Sequel::Rollback
    end

    true
  end
end

RSpec::Matchers.define :destroy do
  match do |actual|
    DB.transaction do
      expect{ actual.destroy.should }.to_not raise_error
      raise Sequel::Rollback
    end

    actual.class.where(id: actual.id).delete

    true
  end
end

RSpec::Matchers.define :survive do
  match do |actual|
    DB.transaction do
      expect{ actual.destroy.should }.to raise_error
      raise Sequel::Rollback
    end

    actual.class.where(id: actual.id).delete

    true
  end
end

def log!
  around(:each) do |e|
    DB.loggers << Logger.new(STDOUT)
    e.run
    DB.loggers = []
  end
end

def assign!(model, fields)
  model.set_all(fields)
end

def read_attribute(model, field)
  model.instance_variable_get("@values")[field]
end