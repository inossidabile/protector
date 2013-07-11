shared_context "paranoidal", paranoid: true do
  before(:all) do
    @paranoid_condition = Protector.paranoid
    Protector.paranoid = true
  end

  after(:all) do
    Protector.paranoid = @paranoid_condition
  end
end

shared_context "adequate", paranoid: false do
  before(:all) do
    @paranoid_condition = Protector.paranoid
    Protector.paranoid = false
  end

  after(:all) do
    Protector.paranoid = @paranoid_condition
  end
end