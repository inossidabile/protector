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
    Dummy.create! string: 'zomgstring', number: 999, text: 'zomgtext'

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

    describe "marks" do
      it "visibility" do
        @dummy.instance_eval do
          protect do
            scope { none }
          end
        end

        @dummy.first.restrict('!').visible?.should == false

        @dummy.instance_eval do
          protect do
            scope { limit(5) }
          end
        end

        @dummy.first.restrict('!').visible?.should == true
      end

      describe "creatability" do
        it "when locked" do
          @dummy.instance_eval do
            protect do; end
          end

          dummy = @dummy.new(string: 'bam', number: 1)
          dummy.restrict('!').creatable?.should == false
        end

        it "by list of fields" do
          @dummy.instance_eval do
            protect do
              can :create, :string
            end
          end

          dummy = @dummy.new(string: 'bam', number: 1)
          dummy.restrict('!').creatable?.should == false

          dummy = @dummy.new(string: 'bam')
          dummy.restrict('!').creatable?.should == true
        end

        it "by lambdas" do
          @dummy.instance_eval do
            protect do
              can :create, string: -> (x) { x.length == 5 }
            end
          end

          dummy = @dummy.new(string: 'bam')
          dummy.restrict('!').creatable?.should == false

          dummy = @dummy.new(string: '12345')
          dummy.restrict('!').creatable?.should == true
        end

        it "by ranges" do
          @dummy.instance_eval do
            protect do
              can :create, number: 0..2
            end
          end

          dummy = @dummy.new(number: 500)
          dummy.restrict('!').creatable?.should == false

          dummy = @dummy.new(number: 2)
          dummy.restrict('!').creatable?.should == true
        end
      end

      describe "updatability" do
        it "when locked" do
          @dummy.instance_eval do
            protect do; end
          end

          dummy = @dummy.first
          dummy.assign_attributes(string: 'bam', number: 1)
          dummy.restrict('!').updatable?.should == false
        end

        it "by list of fields" do
          @dummy.instance_eval do
            protect do
              can :update, :string
            end
          end

          dummy = @dummy.first
          dummy.assign_attributes(string: 'bam', number: 1)
          dummy.restrict('!').updatable?.should == false

          dummy = @dummy.first
          dummy.assign_attributes(string: 'bam')
          dummy.restrict('!').updatable?.should == true
        end

        it "by lambdas" do
          @dummy.instance_eval do
            protect do
              can :update, string: -> (x) { x.length == 5 }
            end
          end

          dummy = @dummy.first
          dummy.assign_attributes(string: 'bam')
          dummy.restrict('!').updatable?.should == false

          dummy = @dummy.first
          dummy.assign_attributes(string: '12345')
          dummy.restrict('!').updatable?.should == true
        end

        it "by ranges" do
          @dummy.instance_eval do
            protect do
              can :update, number: 0..2
            end
          end

          dummy = @dummy.first
          dummy.assign_attributes(number: 500)
          dummy.restrict('!').updatable?.should == false

          dummy = @dummy.first
          dummy.assign_attributes(number: 2)
          dummy.restrict('!').updatable?.should == true
        end
      end

      it "marks destroyability" do
        @dummy.instance_eval do
          protect do
          end
        end

        @dummy.new.restrict('!').destroyable?.should == false

        @dummy.instance_eval do
          protect do
            can :destroy
          end
        end

        @dummy.new.restrict('!').destroyable?.should == true
      end
    end
  end
end