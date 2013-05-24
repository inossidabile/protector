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

shared_examples_for "a model" do
  it "evaluates meta properly" do
    @dummy.instance_eval do
      protect do |subject, dummy|
        subject.should == '!'

        scope { limit(5) }

        can :view
        can :create
        can :update
      end
    end

    fields = Hash[*%w(id string number text created_at updated_at).map{|x| [x, nil]}.flatten]
    dummy  = @dummy.new.restrict('!')
    meta   = dummy.protector_meta

    meta.access[:view].should   == fields
    meta.access[:create].should == fields
    meta.access[:update].should == fields
  end

  describe "association" do
    context "(has_many)" do
      it "passes subject" do
        Dummy.first.restrict('!').fluffies.protector_subject.should == '!'
      end
    end

    context "(belongs_to)" do
      it "passes subject" do
        Fluffy.first.restrict('!').dummy.protector_subject.should == '!'
      end
    end
  end

  describe "visibility" do
    it "marks blocked" do
      @dummy.instance_eval do
        protect do; scope { none }; end
      end

      @dummy.first.restrict('!').visible?.should == false
    end

    it "marks allowed" do
      @dummy.instance_eval do
        protect do; scope { limit(5) }; end
      end

      @dummy.first.restrict('!').visible?.should == true
    end
  end

  describe "readability" do
    it "hides fields" do
      @dummy.instance_eval do
        protect do
          can :view, :string
        end
      end

      dummy = @dummy.first.restrict('!')
      dummy.number.should == nil
      dummy[:number].should == nil
      dummy.read_attribute(:number).should_not == nil
      dummy.string.should == 'zomgstring'
    end
  end

  describe "creatability" do
    context "with empty meta" do
      before(:each) do
        @dummy.instance_eval do
          protect do; end
        end
      end

      it "marks blocked" do
        dummy = @dummy.new(string: 'bam', number: 1)
        dummy.restrict('!').creatable?.should == false
      end

      it "invalidates" do
        dummy = @dummy.new(string: 'bam', number: 1).restrict('!')
        dummy.should invalidate
      end
    end

    context "by list of fields" do
      before(:each) do
        @dummy.instance_eval do
          protect do
            can :create, :string
          end
        end
      end

      it "marks blocked" do
        dummy = @dummy.new(string: 'bam', number: 1)
        dummy.restrict('!').creatable?.should == false
      end

      it "marks allowed" do
        dummy = @dummy.new(string: 'bam')
        dummy.restrict('!').creatable?.should == true
      end

      it "invalidates" do
        dummy = @dummy.new(string: 'bam', number: 1).restrict('!')
        dummy.should invalidate
      end

      it "validates" do
        dummy = @dummy.new(string: 'bam').restrict('!')
        dummy.should validate
      end
    end

    context "by lambdas" do
      before(:each) do
        @dummy.instance_eval do
          protect do
            can :create, string: lambda {|x| x.try(:length) == 5 }
          end
        end
      end

      it "marks blocked" do
        dummy = @dummy.new(string: 'bam')
        dummy.restrict('!').creatable?.should == false
      end

      it "marks allowed" do
        dummy = @dummy.new(string: '12345')
        dummy.restrict('!').creatable?.should == true
      end

      it "invalidates" do
        dummy = @dummy.new(string: 'bam').restrict('!')
        dummy.should invalidate
      end

      it "validates" do
        dummy = @dummy.new(string: '12345').restrict('!')
        dummy.should validate
      end
    end

    context "by ranges" do
      before(:each) do
        @dummy.instance_eval do
          protect do
            can :create, number: 0..2
          end
        end
      end

      it "marks blocked" do
        dummy = @dummy.new(number: 500)
        dummy.restrict('!').creatable?.should == false
      end

      it "marks allowed" do
        dummy = @dummy.new(number: 2)
        dummy.restrict('!').creatable?.should == true
      end

      it "invalidates" do
        dummy = @dummy.new(number: 500).restrict('!')
        dummy.should invalidate
      end

      it "validates" do
        dummy = @dummy.new(number: 2).restrict('!')
        dummy.should validate
      end
    end
  end

  describe "updatability" do
    context "with empty meta" do
      before(:each) do
        @dummy.instance_eval do
          protect do; end
        end
      end

      it "marks blocked" do
        dummy = @dummy.first
        dummy.assign_attributes(string: 'bam', number: 1)
        dummy.restrict('!').updatable?.should == false
      end

      it "invalidates" do
        dummy = @dummy.first.restrict('!')
        dummy.assign_attributes(string: 'bam', number: 1)
        dummy.should invalidate
      end
    end

    context "by list of fields" do
      before(:each) do
        @dummy.instance_eval do
          protect do
            can :update, :string
          end
        end
      end

      it "marks blocked" do
        dummy = @dummy.first
        dummy.assign_attributes(string: 'bam', number: 1)
        dummy.restrict('!').updatable?.should == false
      end

      it "marks allowed" do
        dummy = @dummy.first
        dummy.assign_attributes(string: 'bam')
        dummy.restrict('!').updatable?.should == true
      end

      it "invalidates" do
        dummy = @dummy.first.restrict('!')
        dummy.assign_attributes(string: 'bam', number: 1)
        dummy.should invalidate
      end

      it "validates" do
        dummy = @dummy.first.restrict('!')
        dummy.assign_attributes(string: 'bam')
        dummy.should validate
      end
    end

    context "by lambdas" do
      before(:each) do
        @dummy.instance_eval do
          protect do
            can :update, string: lambda {|x| x.try(:length) == 5 }
          end
        end
      end

      it "marks blocked" do
        dummy = @dummy.first
        dummy.assign_attributes(string: 'bam')
        dummy.restrict('!').updatable?.should == false
      end

      it "marks allowed" do
        dummy = @dummy.first
        dummy.assign_attributes(string: '12345')
        dummy.restrict('!').updatable?.should == true
      end

      it "invalidates" do
        dummy = @dummy.first.restrict('!')
        dummy.assign_attributes(string: 'bam')
        dummy.should invalidate
      end

      it "validates" do
        dummy = @dummy.first.restrict('!')
        dummy.assign_attributes(string: '12345')
        dummy.should validate
      end
    end

    context "by ranges" do
      before(:each) do
        @dummy.instance_eval do
          protect do
            can :update, number: 0..2
          end
        end
      end

      it "marks blocked" do
        dummy = @dummy.first
        dummy.assign_attributes(number: 500)
        dummy.restrict('!').updatable?.should == false
      end

      it "marks allowed" do
        dummy = @dummy.first
        dummy.assign_attributes(number: 2)
        dummy.restrict('!').updatable?.should == true
      end

      it "invalidates" do
        dummy = @dummy.first.restrict('!')
        dummy.assign_attributes(number: 500)
        dummy.should invalidate
      end

      it "validates" do
        dummy = @dummy.first.restrict('!')
        dummy.assign_attributes(number: 2)
        dummy.should validate
      end
    end
  end

  describe "destroyability" do
    it "marks blocked" do
      @dummy.instance_eval do
        protect do; end
      end

      @dummy.first.restrict('!').destroyable?.should == false
    end

    it "marks allowed" do
      @dummy.instance_eval do
        protect do; can :destroy; end
      end

      @dummy.first.restrict('!').destroyable?.should == true
    end

    it "invalidates" do
      @dummy.instance_eval do
        protect do; end
      end

      @dummy.first.restrict('!').destroy.should == false
    end

    it "validates" do
      @dummy.instance_eval do
        protect do; can :destroy; end
      end

      dummy = @dummy.create!.restrict('!')
      dummy.destroy.should == dummy
      dummy.destroyed?.should == true
    end
  end
end