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

    it "throws error for empty subect" do
      base = @base.new
      expect { base.protector_subject }.to raise_error
    end

    it "accepts nil as a subject" do
      base = @base.new.restrict!(nil)
      expect { base.protector_subject }.to_not raise_error
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
      expect { base.protector_subject }.to raise_error
    end
  end

  describe Protector::DSL::Entry do
    before :each do
      @entry = Class.new do
        include Protector::DSL::Entry

        def self.protector_meta
          @protector_meta ||= Protector::DSL::Meta.new nil, nil, []
        end
      end
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
        @meta = Protector::DSL::Meta.new nil, nil, %w(field1 field2 field3 field4 field5)
        @meta << lambda {
          can :view
        }

        @meta << lambda {|user|
          scope { 'relation' } if user
        }

        @meta << lambda {|user|
          user.should  == 'user' if user

          cannot :view, %w(field5), :field4
        }

        @meta << lambda {|user, entry|
          user.should  == 'user' if user
          entry.should == 'entry' if user

          can :update, %w(field1 field2),
            field3: 1,
            field4: 0..5,
            field5: l

          can :destroy
        }
      end

      it "evaluates" do
        @meta.evaluate('user', 'entry')
      end

      context "adequate", paranoid: false do
        it "sets scoped?" do
          data = @meta.evaluate(nil, 'entry')
          data.scoped?.should == false
        end
      end

      context "paranoid", paranoid: true do
        it "sets scoped?" do
          data = @meta.evaluate(nil, 'entry')
          data.scoped?.should == true
        end
      end

      it "sets relation" do
        data = @meta.evaluate('user', 'entry')
        data.relation.should == 'relation'
      end

      it "sets access" do
        data = @meta.evaluate('user', 'entry')
        data.access.should == {
          update: {
            "field1" => nil,
            "field2" => nil,
            "field3" => 1,
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
        data = @meta.evaluate('user', 'entry')
        data.destroyable?.should == true
      end

      it "marks updatable" do
        data = @meta.evaluate('user', 'entry')
        data.updatable?.should == true
      end

      it "gets first unupdatable field" do
        data = @meta.evaluate('user', 'entry')
        data.first_unupdatable_field('field1' => 1, 'field6' => 2, 'field7' => 3).should == 'field6'
      end

      it "marks creatable" do
        data = @meta.evaluate('user', 'entry')
        data.creatable?.should == false
      end

      it "gets first uncreatable field" do
        data = @meta.evaluate('user', 'entry')
        data.first_uncreatable_field('field1' => 1, 'field6' => 2).should == 'field1'
      end
    end

    context "custom methods" do
      before :each do
        @meta = Protector::DSL::Meta.new nil, nil, %w(field1 field2)

        @meta << lambda {
          can :drink, :field1
          can :eat
          cannot :eat, :field1
        }
      end

      it "sets field-level restriction" do
        box = @meta.evaluate('user', 'entry')
        box.can?(:drink, :field1).should == true
        box.can?(:drink).should == true
      end

      it "sets field-level protection" do
        box = @meta.evaluate('user', 'entry')
        box.can?(:eat, :field1).should == false
        box.can?(:eat).should == true
      end
    end
  end
end