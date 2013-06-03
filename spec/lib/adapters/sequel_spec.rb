require 'spec_helpers/boot'

if defined?(Sequel)
  load 'spec_helpers/adapters/sequel.rb'

  describe Protector::Adapters::Sequel do
    before(:all) do
      load 'migrations/sequel.rb'

      module ProtectionCase
        extend ActiveSupport::Concern

        included do |klass|
          protect do |x|
            scope{ where('1=0') } if x == '-'
            scope{ where("#{klass.table_name}__number".to_sym => 999) } if x == '+' 

            can :view, :dummy_id unless x == '-'
          end
        end
      end

      [Dummy, Fluffy].each{|c| c.send :include, ProtectionCase}

      Dummy.create string: 'zomgstring', number: 999, text: 'zomgtext'
      Dummy.create string: 'zomgstring', number: 999, text: 'zomgtext'
      Dummy.create string: 'zomgstring', number: 777, text: 'zomgtext'
      Dummy.create string: 'zomgstring', number: 777, text: 'zomgtext'

      [Fluffy, Bobby].each do |m|
        m.create string: 'zomgstring', number: 999, text: 'zomgtext', dummy_id: 1
        m.create string: 'zomgstring', number: 777, text: 'zomgtext', dummy_id: 1
        m.create string: 'zomgstring', number: 999, text: 'zomgtext', dummy_id: 2
        m.create string: 'zomgstring', number: 777, text: 'zomgtext', dummy_id: 2
      end

      Fluffy.all.each{|f| Loony.create fluffy_id: f.id, string: 'zomgstring' }
    end

    #
    # Model instance
    #
    describe Protector::Adapters::Sequel::Model do
      let(:dummy) do
        Class.new Sequel::Model(:dummies)
      end

      it "includes" do
        Dummy.ancestors.should include(Protector::Adapters::Sequel::Model)
      end

      it "scopes" do
        scope = Dummy.restrict!('!')
        scope.should be_a_kind_of Sequel::Dataset
        scope.protector_subject.should == '!'
      end

      it_behaves_like "a model"
    end

    #
    # Model scope
    #
    describe Protector::Adapters::Sequel::Dataset do
      it "includes" do
        Dummy.none.class.ancestors.should include(Protector::DSL::Base)
      end

      it "saves subject" do
        Dummy.restrict!('!').where(number: 999).protector_subject.should == '!'
      end

      it "forwards subject" do
        Dummy.restrict!('!').where(number: 999).first.protector_subject.should == '!'
        Dummy.restrict!('!').where(number: 999).to_a.first.protector_subject.should == '!'
        Dummy.restrict!('!').eager_graph(fluffies: :loony).all.first.fluffies.first.loony.protector_subject.should == '!'
      end

      context "with null relation" do
        it "checks existence" do
          Dummy.any?.should == true
          Dummy.restrict!('-').any?.should == false
        end

        it "counts" do
          Dummy.count.should == 4
          Dummy.restrict!('-').count.should == 0
        end

        context do
          it "fetches first" do
            Dummy.restrict!('-').first.should == nil
          end
        end

        it "fetches all" do
          fetched = Dummy.restrict!('-').to_a

          Dummy.count.should == 4
          fetched.length.should == 0
        end
      end

      context "with active relation" do
        it "checks existence" do
          Dummy.any?.should == true
          Dummy.restrict!('+').any?.should == true
        end

        it "counts" do
          Dummy.count.should == 4
          Dummy.restrict!('+').count.should == 2
        end

        it "fetches first" do
          Dummy.restrict!('+').first.should be_a_kind_of Dummy
        end

        it "fetches all" do
          fetched = Dummy.restrict!('+').to_a

          Dummy.count.should == 4
          fetched.length.should == 2
        end
      end
    end

    #
    # Eager loading
    #
    describe Protector::Adapters::Sequel::Dataset do
      describe "eager loading" do

        context "straight" do
          it "scopes" do
            d = Dummy.restrict!('+').eager(:fluffies)
            d.count.should == 2
            d.first.fluffies.length.should == 1
          end
        end

        context "graph" do
          it "scopes" do
            d = Dummy.restrict!('+').eager_graph(fluffies: :loony)
            d.count.should == 4
            d = d.all
            d.length.should == 2 # which is terribly sick :doh:
            d.first.fluffies.length.should == 1
            d.first.fluffies.first.loony.should be_a_kind_of Loony
          end
        end
      end
    end
  end

end