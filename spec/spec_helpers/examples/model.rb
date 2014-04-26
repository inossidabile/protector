shared_examples_for "a model" do
  it "evaluates meta properly" do
    dummy.instance_eval do
      protect do |subject, entry|
        subject.should == '!'
        entry.protector_subject?.should == false

        scope { limit(5) }

        can :read
        can :create
        can :update
      end
    end

    fields = Hash[*%w(id string number text dummy_id).map{|x| [x, nil]}.flatten]
    meta   = dummy.new.restrict!('!').protector_meta

    meta.access[:read].should   == fields
    meta.access[:create].should == fields
    meta.access[:update].should == fields
  end

  it "respects inheritance" do
    dummy.instance_eval do
      protect do
        can :read, :test
      end
    end

    attempt = Class.new(dummy) do
      protect do
        can :create, :test
      end
    end

    dummy.protector_meta.evaluate(nil, nil).access.should == {read: {"test"=>nil}}
    attempt.protector_meta.evaluate(nil, nil).access.should == {read: {"test"=>nil}, create: {"test"=>nil}}
  end

  it "drops meta on restrict" do
    d = Dummy.first

    d.restrict!('!').protector_meta
    d.instance_variable_get('@protector_meta').should_not == nil
    d.restrict!('!')
    d.instance_variable_get('@protector_meta').should == nil
  end

  it "doesn't get stuck with non-existing tables" do
    Rumba.class_eval do
      protect do
      end
    end
  end

  describe "visibility" do
    it "marks blocked" do
      Dummy.first.restrict!('-').visible?.should == false
    end

    context "adequate", paranoid: false do
      it "marks allowed" do
        Dummy.first.restrict!('!').visible?.should == true
        Dummy.first.restrict!('+').visible?.should == true
      end
    end

    context "paranoid", paranoid: true do
      it "marks allowed" do
        Dummy.first.restrict!('!').visible?.should == false
        Dummy.first.restrict!('+').visible?.should == true
      end
    end
  end

  #
  # Reading
  #
  describe "readability" do
    it "hides fields" do
      dummy.instance_eval do
        protect do
          can :read, :string
        end
      end

      d = dummy.first.restrict!('!')
      d.number.should == nil
      d[:number].should == nil
      read_attribute(d, :number).should_not == nil
      d.string.should == 'zomgstring'
    end

    it "shows fields" do
      dummy.instance_eval do
        protect do
          can :read, :number
        end
      end

      d = dummy.first.restrict!('!')
      d.number.should_not == nil
      d[:number].should_not == nil
      d['number'].should_not == nil
      read_attribute(d, :number).should_not == nil
    end
  end

  #
  # Creating
  #
  describe "creatability" do
    context "with empty meta" do
      before(:each) do
        dummy.instance_eval do
          protect do; end
        end
      end

      it "handles empty creations" do
        d = dummy.new.restrict!('!')
        d.can?(:create).should == false
        d.creatable?.should == false
        d.should invalidate
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
        d = dummy.new(string: 'bam', number: 1).restrict!('!')
        d.creatable?.should == false
      end

      it "marks allowed" do
        d = dummy.new(string: 'bam').restrict!('!')
        $debug = true
        d.creatable?.should == true
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

    context "by direct values" do
      before(:each) do
        dummy.instance_eval do
          protect do
            can :create, number: 5
          end
        end
      end

      it "marks blocked" do
        d = dummy.new(number: 500)
        d.restrict!('!').creatable?.should == false
      end

      it "marks allowed" do
        d = dummy.new(number: 5)
        d.restrict!('!').creatable?.should == true
      end

      it "invalidates" do
        d = dummy.new(number: 500).restrict!('!')
        d.should invalidate
      end

      it "validates" do
        d = dummy.new(number: 5).restrict!('!')
        d.should validate
      end
    end
  end

  #
  # Updating
  #
  describe "updatability" do
    context "with empty meta" do
      before(:each) do
        dummy.instance_eval do
          protect do; end
        end
      end

      it "marks blocked" do
        d = dummy.first
        assign!(d, string: 'bam', number: 1)
        d.restrict!('!').updatable?.should == false
      end

      it "invalidates" do
        d = dummy.first.restrict!('!')
        assign!(d, string: 'bam', number: 1)
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
        assign!(d, string: 'bam', number: 1)
        d.restrict!('!').updatable?.should == false
      end

      it "marks allowed" do
        d = dummy.first
        assign!(d, string: 'bam')
        d.restrict!('!').updatable?.should == true
      end

      it "invalidates" do
        d = dummy.first.restrict!('!')
        assign!(d, string: 'bam', number: 1)
        d.should invalidate
      end

      it "validates" do
        d = dummy.first.restrict!('!')
        assign!(d, string: 'bam')
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
        assign!(d, string: 'bam')
        d.restrict!('!').updatable?.should == false
      end

      it "marks allowed" do
        d = dummy.first
        assign!(d, string: '12345')
        d.restrict!('!').updatable?.should == true
      end

      it "invalidates" do
        d = dummy.first.restrict!('!')
        assign!(d, string: 'bam')
        d.should invalidate
      end

      it "validates" do
        d = dummy.first.restrict!('!')
        assign!(d, string: '12345')
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
        assign!(d, number: 500)
        d.restrict!('!').updatable?.should == false
      end

      it "marks allowed" do
        d = dummy.first
        assign!(d, number: 2)
        d.restrict!('!').updatable?.should == true
      end

      it "invalidates" do
        d = dummy.first.restrict!('!')
        assign!(d, number: 500)
        d.should invalidate
      end

      it "validates" do
        d = dummy.first.restrict!('!')
        assign!(d, number: 2)
        d.should validate
      end
    end

    context "by direct values" do
      before(:each) do
        dummy.instance_eval do
          protect do
            can :update, number: 5
          end
        end
      end

      it "marks blocked" do
        d = dummy.first
        assign!(d, number: 500)
        d.restrict!('!').updatable?.should == false
      end

      it "marks allowed" do
        d = dummy.first
        assign!(d, number: 5)
        d.restrict!('!').updatable?.should == true
      end

      it "invalidates" do
        d = dummy.first.restrict!('!')
        assign!(d, number: 500)
        d.should invalidate
      end

      it "validates" do
        d = dummy.first.restrict!('!')
        assign!(d, number: 5)
        d.should validate
      end
    end
  end

  #
  # Destroying
  #
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

      d = dummy.create.restrict!('!')
      d.should survive
    end

    it "validates" do
      dummy.instance_eval do
        protect do; can :destroy; end
      end

      d = dummy.create.restrict!('!')
      d.should destroy
    end
  end

  #
  # Associations
  #
  describe "association" do
    context "(has_many)" do
      context "adequate", paranoid: false do
        it "loads" do
          Dummy.first.restrict!('!').fluffies.length.should == 2
          Dummy.first.restrict!('+').fluffies.length.should == 1
          Dummy.first.restrict!('-').fluffies.empty?.should == true
        end
      end
      context "paranoid", paranoid: true do
        it "loads" do
          Dummy.first.restrict!('!').fluffies.empty?.should == true
          Dummy.first.restrict!('+').fluffies.length.should == 1
          Dummy.first.restrict!('-').fluffies.empty?.should == true
        end
      end
    end

    context "(belongs_to)" do
      context "adequate", paranoid: false do
        it "passes subject" do
          Fluffy.first.restrict!('!').dummy.protector_subject.should == '!'
        end

        it "loads" do
          Fluffy.first.restrict!('!').dummy.should be_a_kind_of(Dummy)
          Fluffy.first.restrict!('-').dummy.should == nil
        end
      end

      context "paranoid", paranoid: true do
        it "loads" do
          Fluffy.first.restrict!('!').dummy.should == nil
          Fluffy.first.restrict!('-').dummy.should == nil
        end
      end
    end
  end
end