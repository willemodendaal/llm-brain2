defmodule Brain2.Mind.Thought do
  use Ash.Resource,
    domain: Brain2.Mind,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "thoughts"
    repo Brain2.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :content, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :brain, Brain2.Mind.Brain, allow_nil?: false, public?: true
    has_many :emotion_changes, Brain2.Mind.EmotionChange
  end

  actions do
    defaults [:read, :destroy]

    create :record do
      accept [:content]
      argument :brain_id, :uuid, allow_nil?: false
      change manage_relationship(:brain_id, :brain, type: :append_and_remove)
    end
  end
end
