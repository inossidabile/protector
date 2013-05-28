require 'spec_helpers/boot'

if defined?(ActiveRecord)

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

  describe Protector::Adapters::ActiveRecord do
    before(:all) do
      ActiveRecord::Schema.verbose = false
      ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

      ActiveRecord::Migration.create_table :dummies do |t|
        t.string      :string
        t.integer     :number
        t.text        :text
        t.timestamps
      end

      ActiveRecord::Migration.create_table :fluffies do |t|
        t.string      :string
        t.integer     :number
        t.belongs_to  :dummy
        t.timestamps
      end

      Protector::Adapters::ActiveRecord.activate!

      class Dummy < ActiveRecord::Base
        protect do |x|
          scope{ where('1=0') } if x == '-'
          scope{ where(number: 999) } if x == '+'
        end

        scope :none, where('1 = 0') unless respond_to?(:none)
        has_many :fluffies
      end
      Dummy.create! string: 'zomgstring', number: 999, text: 'zomgtext'
      Dummy.create! string: 'zomgstring', number: 777, text: 'zomgtext'

      class Fluffy < ActiveRecord::Base
        protect do |x|
          scope{ where('1=0') } if x == '-'
          scope{ where(number: 999) } if x == '+'

          can :view, :dummy_id unless x == '-'
        end

        scope :none, where('1 = 0') unless respond_to?(:none)
        belongs_to :dummy
      end
      Fluffy.create! string: 'zomgstring', number: 999, dummy_id: 1
      Fluffy.create! string: 'zomgstring', number: 777, dummy_id: 1
    end

    describe Protector::Adapters::ActiveRecord::Base do
      before(:each) do
        @dummy = Class.new(ActiveRecord::Base) do
          self.table_name = "dummies"
          scope :none, where('1 = 0') unless respond_to?(:none)
        end
      end

      it "includes" do
        @dummy.ancestors.should include(Protector::Adapters::ActiveRecord::Base)
      end

      it "scopes" do
        @dummy.instance_eval do
          protect do; scope{ all }; end
        end

        scope = @dummy.restrict!('!')
        scope.should be_a_kind_of ActiveRecord::Relation
        scope.protector_subject.should == '!'
      end

      it_behaves_like "a model"

      describe "eager loading" do
        # around(:each) do |e|
        #   ActiveRecord::Base.logger = Logger.new(STDOUT)
        #   e.run
        #   ActiveRecord::Base.logger = nil
        # end

        it "scopes" do
          dummy = Dummy.restrict!('+').includes(:fluffies).first
          dummy.fluffies.length.should == 1
        end
      end
    end

    describe Protector::Adapters::ActiveRecord::Relation do
      before(:all) do
        @dummy = Class.new(ActiveRecord::Base) do
          self.table_name = "dummies"
          scope :none, where('1 = 0') unless respond_to?(:none)
        end
      end

      it "includes" do
        @dummy.none.ancestors.should include(Protector::Adapters::ActiveRecord::Base)
      end

      it "saves subject" do
        @dummy.restrict!('!').where(number: 999).protector_subject.should == '!'
      end

      it "forwards subject" do
        @dummy.instance_eval do
          protect do; end
        end

        @dummy.restrict!('!').where(number: 999).first.protector_subject.should == '!'
        @dummy.restrict!('!').where(number: 999).to_a.first.protector_subject.should == '!'
      end

      context "with null relation" do
        before(:each) do
          @dummy.instance_eval do
            protect do; scope{ none }; end
          end
        end

        it "checks existence" do
          @dummy.any?.should == true
          @dummy.restrict!('!').any?.should == false
        end

        it "counts" do
          @dummy.count.should == 2
          @dummy.restrict!('!').count.should == 0
        end

        it "fetches" do
          fetched = @dummy.restrict!('!').to_a

          @dummy.all.length.should == 2
          fetched.length.should == 0
        end

        it "keeps security scope when unscoped" do
          @dummy.unscoped.restrict!('!').count.should == 0
          @dummy.restrict!('!').unscoped.count.should == 0
        end
      end

      context "with active relation" do
        before(:each) do
          @dummy.instance_eval do
            protect do; scope{ where(number: 999) }; end
          end
        end

        it "checks existence" do
          @dummy.any?.should == true
          @dummy.restrict!('!').any?.should == true
        end

        it "counts" do
          @dummy.count.should == 2
          @dummy.restrict!('!').count.should == 1
        end

        it "fetches" do
          fetched = @dummy.restrict!('!').to_a

          @dummy.all.length.should == 2
          fetched.length.should == 1
        end

        it "keeps security scope when unscoped" do
          @dummy.unscoped.restrict!('!').count.should == 1
          @dummy.restrict!('!').unscoped.count.should == 1
        end
      end
    end
  end

end