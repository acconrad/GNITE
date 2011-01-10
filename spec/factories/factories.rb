Factory.sequence(:name_string) do |i|
  "taxon #{i}"
end

Factory.define :tree do |tree|
  tree.title { "My Tree" }
  tree.association      :user, :factory => :email_confirmed_user
  tree.creative_commons { 'cc0' }
end

Factory.define :master_tree, :parent => :tree, :class => 'MasterTree' do |master_tree|
end

Factory.define :reference_tree, :parent => :tree, :class => 'ReferenceTree' do |reference_tree|
  reference_tree.association :master_tree
end

Factory.define :node do |node|
  node.association :tree
  node.association :name
  node.rank { 'Family' }
end

Factory.define :name do |name|
  name.name_string { Factory.next(:name_string) }
end

Factory.define :synonym do |synonym|
  synonym.association :node
  synonym.association :name
end

Factory.define :vernacular_name do |vernacular|
  vernacular.association :node
  vernacular.association :name
end

Factory.define :gnaclr_importer do |gnaclr_importer|
  gnaclr_importer.association :reference_tree
  gnaclr_importer.url {'foo'}
end

Factory.define :action_rename_node do |action_rename_node|
  action_rename_node.association :user
  action_rename_node.node_id { Factory(:node).id }
  action_rename_node.old_name { |a| Node.find(a.node_id).name.name_string }
  action_rename_node.new_name { Factory.next(:name_string) }
end
