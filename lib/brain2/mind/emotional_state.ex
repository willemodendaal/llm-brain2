defmodule Brain2.Mind.EmotionalState do
  use Ash.Resource,
    domain: Brain2.Mind,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("emotional_states")
    repo(Brain2.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:level, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:default_level, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:prompt_injection, :string, allow_nil?: false, public?: true)
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  validations do
    validate(present(:name))
    validate(numericality(:level, greater_than_or_equal_to: 0, less_than_or_equal_to: 100))

    validate(
      numericality(:default_level, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    )
  end

  relationships do
    belongs_to :brain, Brain2.Mind.Brain, allow_nil?: false, public?: true
  end

  actions do
    defaults([:read, :destroy])

    create :add do
      accept([:name, :level, :default_level, :prompt_injection])
      argument(:brain_id, :uuid, allow_nil?: false)
      change(manage_relationship(:brain_id, :brain, type: :append_and_remove))
    end

    update :set_level do
      accept([:level])
    end

    update :reset_to_default do
      require_atomic?(false)

      change(fn changeset, _ ->
        default = Ash.Changeset.get_attribute(changeset, :default_level)
        Ash.Changeset.force_change_attribute(changeset, :level, default)
      end)
    end
  end
end
