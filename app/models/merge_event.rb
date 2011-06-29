class MergeEvent < ActiveRecord::Base
  belongs_to :master_tree
  belongs_to :user
  belongs_to :node, :foreign_key => :primary_node_id
  belongs_to :node, :foreign_key => :secondary_node_id
  belongs_to :merge_tree

  has_many :merge_result_primaries
  @queue = :merge_event
  
  def self.perform(merge_event_id)
    me = MergeEvent.find(merge_event_id)
    me.merge
    MergeResultPrimary.import_merge(me)
    me.status = "in review"
    me.save!
  end

  def merge
    unless @merge_data
      primary_data = Node.find(primary_node_id).merge_data
      secondary_data = Node.find(secondary_node_id).merge_data
      fr = FamilyReunion.new(primary_data, secondary_data)
      FamilyReunion.logger.subscribe(:an_object_id => fr.object_id, :tree_id => self.master_tree_id, :job_type => 'MergeEvent')
      @merge_data = fr.merge
    end
    @merge_data
  end
  
  def make_merged_tree
    self.update_attributes(:merge_tree => MergeTree.create!)
    unless self.merge_result_primaries.limit(1).empty?
      root_node = self.primary_node.deep_merge(self)
      root_node.parent = self.merge_tree.root
      root_node.save!
      root_node.reload
    end
    self.merge_tree
  end

  def primary_node
    @primary_node ||= Node.find(primary_node_id)
  end

  def secondary_node
    @secondary_node ||= Node.find(secondary_node_id)
  end

end
