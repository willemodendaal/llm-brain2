defmodule Brain2.Mind.EmotionChange do
  use Ash.Resource,
    domain: Brain2.Mind,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "emotion_changes"
    repo Brain2.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :emotion_name, :string, allow_nil?: false, public?: true
    attribute :delta, :integer, allow_nil?: false, public?: true
    attribute :from_level, :integer, allow_nil?: false, public?: true
    attribute :to_level, :integer, allow_nil?: false, public?: true
    attribute :reason, :string, public?: true
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :brain, Brain2.Mind.Brain, allow_nil?: false, public?: true
    belongs_to :thought, Brain2.Mind.Thought, allow_nil?: true, public?: true
  end

  actions do
    defaults [:read, :destroy]

    create :record do
      accept [:emotion_name, :delta, :from_level, :to_level, :reason, :thought_id]
      argument :brain_id, :uuid, allow_nil?: false
      change manage_relationship(:brain_id, :brain, type: :append_and_remove)
    end
  end
end
