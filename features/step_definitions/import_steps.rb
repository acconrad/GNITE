When /^I type the following node names into the import box:$/ do |node_names_table|
  When %{I fill in "Import List of Nodes" with "#{node_names_table.raw.join("\n")}"}
end
