require 'spec_helpers/boot'

describe Protector::DSL do
  describe Protector::DSL::Base do
    before :each do
      @base = Class.new{ include Protector::DSL::Base }
    end

    it "defines proper methods" do
      @base.instance_methods.should include(:restrict!)
      @base.instance_methods.should include(:protector_subject)
    end

    it "remembers protection subject" do
      base = @base.new
      base.restrict!("universe")
      base.protector_subject.should == "universe"
    end

    it "forgets protection subject" do
      base = @base.new
      base.restrict!("universe")
      base.protector_subject.should == "universe"
      base.unrestrict!
      base.protector_subject.should == nil
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
    context "basic methods" do
      l = lambda {|x| x > 4 }

      before :each do
        @meta = Protector::DSL::Meta.new

        @meta << lambda {
          scope { 'relation' }
        }

        @meta << lambda {|user|
          user.should  == 'user'

          can    :view
          cannot :view, %w(field5), :field4
        }

        @meta << lambda {|user, entry|
          user.should  == 'user'
          entry.should == 'entry'

          can :update, %w(field1 field2 field3),
            field4: 0..5,
            field5: l

          can :destroy
        }
      end

      it "evaluates" do
        @meta.evaluate(nil, 'user', [], 'entry')
      end

      it "sets relation" do
        data = @meta.evaluate(nil, 'user', [], 'entry')
        data.relation.should == 'relation'
      end

      it "sets access" do
        data = @meta.evaluate(nil, 'user', %w(field1 field2 field3 field4 field5), 'entry')
        data.access.should == {
          update: {
            "field1" => nil,
            "field2" => nil,
            "field3" => nil,
            "field4" => 0..5,
            "field5" => l
          },
          view: {
            "field1" => nil,
            "field2" => nil,
            "field3" => nil
          },
          create: {}
        }
      end

      it "marks destroyable" do
        data = @meta.evaluate(nil, 'user', [], 'entry')
        data.destroyable?.should == true
      end

      it "marks updatable" do
        data = @meta.evaluate(nil, 'user', [], 'entry')
        data.updatable?.should == true
      end

      it "marks creatable" do
        data = @meta.evaluate(nil, 'user', [], 'entry')
        data.creatable?.should == false
      end
    end

    context "custom methods" do
      before :each do
        @meta = Protector::DSL::Meta.new

        @meta << lambda {
          can :drink, :field1
          can :eat
          cannot :eat, :field1
        }
      end

      it "sets field-level restriction" do
        box = @meta.evaluate(nil, 'user', %w(field1 field2), 'entry')
        box.can?(:drink, :field1).should == true
        box.can?(:drink).should == true
      end

      it "sets field-level protection" do
        box = @meta.evaluate(nil, 'user', %w(field1 field2), 'entry')
        box.can?(:eat, :field1).should == false
        box.can?(:eat).should == true
      end
    end
  end
end