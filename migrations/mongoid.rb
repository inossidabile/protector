Mongoid.configure do |config|
  Mongoid::Sessions.disconnect
  Mongoid::Sessions.clear
  
  config.load_configuration({
    "sessions" => {
      "default" => {
        "database" => "protector_spec",
        "hosts" => [
          "localhost:27017"
        ]
      }
    },
    "database" => "protector_spec"
  })

  config.purge!
end

class Dummy
  include Mongoid::Document

  field :string, type: String
  field :number, type: Integer
  field :text,   type: String

  has_many :fluffies
  has_many :bobbies
end

class Fluffy
  include Mongoid::Document

  field :string, type: String
  field :number, type: Integer
  field :text,   type: String

  belongs_to :dummy
  has_one :loony
end

class Bobby
  include Mongoid::Document

  field :string, type: String
  field :number, type: Integer
  field :text,   type: String

  belongs_to :dummy
end

class Loony
  include Mongoid::Document

  field :string, type: String

  belongs_to :fluffy
end
