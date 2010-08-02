class NodesController < ApplicationController
  def index
    respond_to do |format|
      format.json do
        # root = Node.find(params[:parent_id]) rescue nil
        # nodes = root ? root.children : Node.roots
        nodes = current_user.trees.find(params[:tree_id]).nodes

        node_hashes = nodes.map do |node|
          node_hash = {
            :data => node.name,
            :attr => { :id => node.id }
          }

          # node_hash[:state] = 'closed' if node.has_children?
          # node_hash
        end

        render :json => node_hashes
      end
    end
  end

end
