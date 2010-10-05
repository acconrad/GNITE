class Node < ActiveRecord::Base
  validates_presence_of :name, :tree_id
  belongs_to :tree
  belongs_to :name

  has_many :synonyms
  has_many :vernacular_names

  has_ancestry

  delegate :name_string, :to => :name

  def self.find_by_id_for_user(id_to_find, user)
    # If we just called user.master_tree_ids here,
    # AR wouldn't load all the tree columns, causing Tree#after_initialize to fail when trying to read self.uuid
    tree_ids = user.master_trees.map(&:id) | user.reference_trees.map(&:id)
    find(:first, :conditions => ["id = ? and tree_id in (?)", id_to_find, tree_ids])
  end

  def deep_copy_to(tree)
    copy = self.clone
    copy.tree = tree
    copy.save

    children.each do |child|
      child_copy = child.deep_copy_to(tree)
      child_copy.parent = copy
      child_copy.save
    end

    vernacular_names.each do |vernacular_name|
      vernacular_name_copy = vernacular_name.clone
      vernacular_name_copy.node = copy
      vernacular_name_copy.save
    end

    synonyms.each do |synonym|
      synonym_copy = synonym.clone
      synonym_copy.node = copy
      synonym_copy.save
    end

    copy.reload
  end

  def rank_string
    rank_string = rank.to_s.strip
    rank_string = 'None' if rank_string.empty?
    rank_string
  end

  def synonym_name_strings
    synonyms.all(:include => :name).map(&:name).compact.map(&:name_string).tap do |name_strings|
      name_strings << 'None' if name_strings.empty?
    end
  end

  def vernacular_name_strings
    vernacular_names.all(:include => :name).map(&:name).compact.map(&:name_string).tap do |name_strings|
      name_strings << 'None' if name_strings.empty?
    end
  end
end
