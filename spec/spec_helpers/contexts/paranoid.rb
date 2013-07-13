shared_context "paranoidal", paranoid: true do
  before(:all) do
    @paranoid_condition = Protector.config.paranoid?
    Protector.config.paranoid = true
  end

  after(:all) do
    Protector.config.paranoid = @paranoid_condition
  end
end

shared_context "adequate", paranoid: false do
  before(:all) do
    @paranoid_condition = Protector.config.paranoid?
    Protector.config.paranoid = false
  end

  after(:all) do
    Protector.config.paranoid = @paranoid_condition
  end
end