require 'spec_helpers/boot'

if defined?(ActiveRecord)

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
        t.belongs_to  :dummy
        t.timestamps
      end

      Protector::Adapters::ActiveRecord.activate!

      class Dummy < ActiveRecord::Base
        protect do; end
        has_many :fluffies
      end
      Dummy.create! string: 'zomgstring', number: 999, text: 'zomgtext'
      Dummy.create! string: 'zomgstring', number: 777, text: 'zomgtext'

      class Fluffy < ActiveRecord::Base
        protect do
          can :view, :dummy_id
        end
        belongs_to :dummy
      end
      Fluffy.create! string: 'zomgstring', dummy_id: 1
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

        scope = @dummy.restrict('!')
        scope.should be_a_kind_of ActiveRecord::Relation
        scope.protector_subject.should == '!'
      end

      it_behaves_like "a model"
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
        @dummy.restrict('!').where(number: 999).protector_subject.should == '!'
      end

      context "with null relation" do
        before(:each) do
          @dummy.instance_eval do
            protect do; scope{ none }; end
          end
        end

        it "counts" do
          @dummy.count.should == 2
          @dummy.restrict('!').count.should == 0
        end

        it "fetches" do
          fetched = @dummy.restrict('!').to_a

          @dummy.all.length.should == 2
          fetched.length.should == 0
        end
      end

      context "with active relation" do
        before(:each) do
          @dummy.instance_eval do
            protect do; scope{ where(number: 999) }; end
          end
        end

        it "counts" do
          @dummy.count.should == 2
          @dummy.restrict('!').count.should == 1
        end

        it "fetches" do
          fetched = @dummy.restrict('!').to_a

          @dummy.all.length.should == 2
          fetched.length.should == 1
        end
      end
    end
  end

end