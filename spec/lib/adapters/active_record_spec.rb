require 'spec_helpers/boot'

describe Protector::Adapters::ActiveRecord do
  before(:all) do
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
    ActiveRecord::Migration.create_table :dummies do |t|
      t.string  :string
      t.integer :number
      t.text    :text
      t.timestamps
    end

    class Dummy < ActiveRecord::Base; end
    Dummy.create! string: 'zomgstring', number: 999, text: 'zomgtext'
    Dummy.create! string: 'zomgstring', number: 777, text: 'zomgtext'

    Protector::Adapters::ActiveRecord.activate!
  end

  describe Protector::Adapters::ActiveRecord::Base do
    before(:each) do
      @dummy = Class.new(ActiveRecord::Base) do
        self.table_name = "dummies"
      end
    end

    it "includes" do
      @dummy.ancestors.should include(Protector::Adapters::ActiveRecord::Base)
    end

    it "scopes" do
      scope = @dummy.restrict('!')
      scope.should be_an_instance_of ActiveRecord::Relation
      scope.protector_subject.should == '!'
    end

    it_behaves_like "a model"
  end

  describe Protector::Adapters::ActiveRecord::Relation do
    before(:all) do
      @dummy = Class.new(ActiveRecord::Base) do
        self.table_name = "dummies"
      end
    end

    it "includes" do
      @dummy.all.ancestors.should include(Protector::Adapters::ActiveRecord::Base)
    end

    it "saves subject" do
      @dummy.all.restrict('!').where(number: 999).protector_subject.should == '!'
    end

    context "with null relation" do
      before(:each) do
        @dummy.instance_eval do
          protect{ scope{ none } }
        end
      end

      it "counts" do
        @dummy.all.count.should == 2
        @dummy.all.restrict('!').count.should == 0
      end

      it "fetches" do
        fetched = @dummy.all.restrict('!').to_a

        @dummy.all.to_a.length.should == 2
        fetched.length.should == 0
      end
    end

    context "with active relation" do
      before(:each) do
        @dummy.instance_eval do
          protect{ scope{ where(number: 999) } }
        end
      end

      it "counts" do
        @dummy.all.count.should == 2
        @dummy.all.restrict('!').count.should == 1
      end

      it "fetches" do
        fetched = @dummy.all.restrict('!').to_a

        @dummy.all.to_a.length.should == 2
        fetched.length.should == 1
      end
    end
  end
end