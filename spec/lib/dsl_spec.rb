require 'spec_helper'

describe Protector::DSL do
  describe Protector::DSL::Base do
    before :each do
      @base = Class.new{ include Protector::DSL::Base }
    end

    it "defines proper methods" do
      @base.instance_methods.should include(:restrict)
      @base.instance_methods.should include(:protector_subject)
    end

    it "remembers protection subject" do
      base = @base.new
      base.restrict("universe")
      base.protector_subject.should == "universe"
    end
  end

  describe Protector::DSL::Entry do
    before :each do
      @entry = Class.new{ include Protector::DSL::Entry }
    end

    it "instantiates meta entity" do
      @entry.instance_eval do
        protect do; end
      end

      @entry.protector_meta.should be_an_instance_of(Protector::DSL::Meta)
    end
  end

  describe Protector::DSL::Meta do
    l = -> (x) { x > 4 }

    before :each do
      @meta = Protector::DSL::Meta.new

      # << -> FTW!
      @meta << -> {
        scope { 'relation' }
      }

      @meta << -> (user) {
        user.should  == 'user'

        can    :view
        cannot :view, %w(field5), :field4
      }

      @meta << -> (user, entry) {
        user.should  == 'user'
        entry.should == 'entry'

        can :update, %w(field1 field2 field3),
          field4: 0..5,
          field5: l

        can :destroy
      }
    end

    it "evaluates" do
      @meta.evaluate(nil, [], 'user', 'entry')
    end

    it "sets relation" do
      data = @meta.evaluate(nil, [], 'user', 'entry')
      data.relation.should == 'relation'
    end

    it "sets access" do
      data = @meta.evaluate(nil, %w(field1 field2 field3 field4 field5), 'user', 'entry')
      data.access.should == {
        "update" => {
          "field1" => nil,
          "field2" => nil,
          "field3" => nil,
          "field4" => 0..5,
          "field5" => l
        },
        "view" => {
          "field1" => nil,
          "field2" => nil,
          "field3" => nil
        },
        "create" => {}
      }
    end

    it "marks destroyable" do
      data = @meta.evaluate(nil, [], 'user', 'entry')
      data.destroyable?.should == true
    end

    it "marks updatable" do
      data = @meta.evaluate(nil, [], 'user', 'entry')
      data.updatable?.should == true
    end
  end
end