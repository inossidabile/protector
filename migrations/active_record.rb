### Connection

ActiveRecord::Schema.verbose = false
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

ActiveRecord::Base.instance_eval do
  unless method_defined?(:none)
    def none
      where('1 = 0')
    end
  end

  def every
    where(nil)
  end
end

### Tables

[:dummies, :fluffies, :bobbies].each do |m|
  ActiveRecord::Migration.create_table m do |t|
    t.string      :string
    t.integer     :number
    t.text        :text
    t.belongs_to  :dummy
  end
end

ActiveRecord::Migration.create_table(:loonies){|t| t.belongs_to :fluffy; t.string :string }

### Classes

class Dummy < ActiveRecord::Base
  has_many :fluffies
  has_many :bobbies
end

class Fluffy < ActiveRecord::Base
  belongs_to :dummy
  has_one :loony
end

class Bobby < ActiveRecord::Base
end

class Loony < ActiveRecord::Base
end