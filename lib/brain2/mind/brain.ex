defmodule Brain2.Mind.Brain do
  use Ash.Resource,
    domain: Brain2.Mind,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("brains")
    repo(Brain2.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  validations do
    validate(present(:name), message: "can't be blank")
    validate(string_length(:name, min: 1), message: "can't be blank")
  end

  relationships do
    has_many :emotional_states, Brain2.Mind.EmotionalState
    has_many :messages, Brain2.Mind.Message
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name])
    end

    update :rename do
      accept([:name])
    end
  end
end
