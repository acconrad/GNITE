class MasterTree < Tree
  has_many :reference_trees
  belongs_to :user
end
