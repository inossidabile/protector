require 'spec_helper'

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
    Dummy.create! string: 'test', number: 1, text: 'test'

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

    it "evaluates meta properly" do
      @dummy.instance_eval do
        protect do |subject, dummy|
          subject.should == 'test'

          scope { limit(5) }

          can :view
          can :create
          can :update
        end
      end

      fields = Hash[*%w(id string number text created_at updated_at).map{|x| [x, nil]}.flatten]
      dummy  = @dummy.new.restrict('test')
      meta   = dummy.protector_meta

      meta.access[:view].should   == fields
      meta.access[:create].should == fields
      meta.access[:update].should == fields
    end

    it "marks visibility" do
      @dummy.instance_eval do
        protect do
          scope { none }
        end
      end

      @dummy.find(1).restrict('test').visible?.should == false

      @dummy.instance_eval do
        protect do
          scope { limit(5) }
        end
      end

      @dummy.find(1).restrict('test').visible?.should == true
    end

    it "marks creatability" do
      @dummy.instance_eval do
        protect do; end
      end

      dummy = @dummy.new(string: 'test', number: 1)
      dummy.restrict('test').creatable?.should == false
    end
  end
end