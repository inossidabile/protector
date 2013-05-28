shared_examples_for "a model" do
  it "evaluates meta properly" do
    dummy.instance_eval do
      protect do |subject, dummy|
        subject.should == '!'

        scope { limit(5) }

        can :view
        can :create
        can :update
      end
    end

    fields = Hash[*%w(id string number text dummy_id created_at updated_at).map{|x| [x, nil]}.flatten]
    meta   = dummy.new.restrict!('!').protector_meta

    meta.access[:view].should   == fields
    meta.access[:create].should == fields
    meta.access[:update].should == fields
  end

  describe "association" do
    context "(has_many)" do
      it "loads" do
        Dummy.first.restrict!('!').fluffies.length.should == 2
        Dummy.first.restrict!('+').fluffies.length.should == 1
        Dummy.first.restrict!('-').fluffies.empty?.should == true
      end
    end

    context "(belongs_to)" do
      it "passes subject" do
        Fluffy.first.restrict!('!').dummy.protector_subject.should == '!'
      end

      it "loads" do
        Fluffy.first.restrict!('!').dummy.should be_a_kind_of(Dummy)
        Fluffy.first.restrict!('-').dummy.should == nil
      end
    end
  end

  describe "visibility" do
    it "marks blocked" do
      Dummy.first.restrict!('-').visible?.should == false
    end

    it "marks allowed" do
      Dummy.first.restrict!('+').visible?.should == true
    end
  end

  describe "readability" do
    it "hides fields" do
      dummy.instance_eval do
        protect do
          can :view, :string
        end
      end

      d = dummy.first.restrict!('!')
      d.number.should == nil
      d[:number].should == nil
      d.read_attribute(:number).should_not == nil
      d.string.should == 'zomgstring'
    end
  end

  describe "creatability" do
    context "with empty meta" do
      before(:each) do
        dummy.instance_eval do
          protect do; end
        end
      end

      it "marks blocked" do
        d = dummy.new(string: 'bam', number: 1)
        d.restrict!('!').creatable?.should == false
      end

      it "invalidates" do
        d = dummy.new(string: 'bam', number: 1).restrict!('!')
        d.should invalidate
      end
    end

    context "by list of fields" do
      before(:each) do
        dummy.instance_eval do
          protect do
            can :create, :string
          end
        end
      end

      it "marks blocked" do
        d = dummy.new(string: 'bam', number: 1)
        d.restrict!('!').creatable?.should == false
      end

      it "marks allowed" do
        d = dummy.new(string: 'bam')
        d.restrict!('!').creatable?.should == true
      end

      it "invalidates" do
        d = dummy.new(string: 'bam', number: 1).restrict!('!')
        d.should invalidate
      end

      it "validates" do
        d = dummy.new(string: 'bam').restrict!('!')
        d.should validate
      end
    end

    context "by lambdas" do
      before(:each) do
        dummy.instance_eval do
          protect do
            can :create, string: lambda {|x| x.try(:length) == 5 }
          end
        end
      end

      it "marks blocked" do
        d = dummy.new(string: 'bam')
        d.restrict!('!').creatable?.should == false
      end

      it "marks allowed" do
        d = dummy.new(string: '12345')
        d.restrict!('!').creatable?.should == true
      end

      it "invalidates" do
        d = dummy.new(string: 'bam').restrict!('!')
        d.should invalidate
      end

      it "validates" do
        d = dummy.new(string: '12345').restrict!('!')
        d.should validate
      end
    end

    context "by ranges" do
      before(:each) do
        dummy.instance_eval do
          protect do
            can :create, number: 0..2
          end
        end
      end

      it "marks blocked" do
        d = dummy.new(number: 500)
        d.restrict!('!').creatable?.should == false
      end

      it "marks allowed" do
        d = dummy.new(number: 2)
        d.restrict!('!').creatable?.should == true
      end

      it "invalidates" do
        d = dummy.new(number: 500).restrict!('!')
        d.should invalidate
      end

      it "validates" do
        d = dummy.new(number: 2).restrict!('!')
        d.should validate
      end
    end
  end

  describe "updatability" do
    context "with empty meta" do
      before(:each) do
        dummy.instance_eval do
          protect do; end
        end
      end

      it "marks blocked" do
        d = dummy.first
        d.assign_attributes(string: 'bam', number: 1)
        d.restrict!('!').updatable?.should == false
      end

      it "invalidates" do
        d = dummy.first.restrict!('!')
        d.assign_attributes(string: 'bam', number: 1)
        d.should invalidate
      end
    end

    context "by list of fields" do
      before(:each) do
        dummy.instance_eval do
          protect do
            can :update, :string
          end
        end
      end

      it "marks blocked" do
        d = dummy.first
        d.assign_attributes(string: 'bam', number: 1)
        d.restrict!('!').updatable?.should == false
      end

      it "marks allowed" do
        d = dummy.first
        d.assign_attributes(string: 'bam')
        d.restrict!('!').updatable?.should == true
      end

      it "invalidates" do
        d = dummy.first.restrict!('!')
        d.assign_attributes(string: 'bam', number: 1)
        d.should invalidate
      end

      it "validates" do
        d = dummy.first.restrict!('!')
        d.assign_attributes(string: 'bam')
        d.should validate
      end
    end

    context "by lambdas" do
      before(:each) do
        dummy.instance_eval do
          protect do
            can :update, string: lambda {|x| x.try(:length) == 5 }
          end
        end
      end

      it "marks blocked" do
        d = dummy.first
        d.assign_attributes(string: 'bam')
        d.restrict!('!').updatable?.should == false
      end

      it "marks allowed" do
        d = dummy.first
        d.assign_attributes(string: '12345')
        d.restrict!('!').updatable?.should == true
      end

      it "invalidates" do
        d = dummy.first.restrict!('!')
        d.assign_attributes(string: 'bam')
        d.should invalidate
      end

      it "validates" do
        d = dummy.first.restrict!('!')
        d.assign_attributes(string: '12345')
        d.should validate
      end
    end

    context "by ranges" do
      before(:each) do
        dummy.instance_eval do
          protect do
            can :update, number: 0..2
          end
        end
      end

      it "marks blocked" do
        d = dummy.first
        d.assign_attributes(number: 500)
        d.restrict!('!').updatable?.should == false
      end

      it "marks allowed" do
        d = dummy.first
        d.assign_attributes(number: 2)
        d.restrict!('!').updatable?.should == true
      end

      it "invalidates" do
        d = dummy.first.restrict!('!')
        d.assign_attributes(number: 500)
        d.should invalidate
      end

      it "validates" do
        d = dummy.first.restrict!('!')
        d.assign_attributes(number: 2)
        d.should validate
      end
    end
  end

  describe "destroyability" do
    it "marks blocked" do
      dummy.instance_eval do
        protect do; end
      end

      dummy.first.restrict!('!').destroyable?.should == false
    end

    it "marks allowed" do
      dummy.instance_eval do
        protect do; can :destroy; end
      end

      dummy.first.restrict!('!').destroyable?.should == true
    end

    it "invalidates" do
      dummy.instance_eval do
        protect do; end
      end

      dummy.first.restrict!('!').destroy.should == false
    end

    it "validates" do
      dummy.instance_eval do
        protect do; can :destroy; end
      end

      d = dummy.create!.restrict!('!')
      d.destroy.should == d
      d.destroyed?.should == true
    end
  end
end