class MasterTreesController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource

  layout 'master_trees'

  def index
    accessible_trees = MasterTree.accessible_by(current_ability).includes([:user, :merge_events])
    master_trees = []
    accessible_trees.each do |tree|
      master_trees << tree if tree.user_id == current_user.id
    end
    @master_trees = master_trees.sort { |a,b| a.title.downcase <=> b.title.downcase }
    @accessible_trees = (accessible_trees - master_trees).sort { |a,b| a.title.downcase <=> b.title.downcase }
  end

  def new
    @master_tree = MasterTree.new(title: 'New Working Tree')
    @master_tree.user = current_user
    @master_tree.user_id = current_user.id
    @master_tree.save
    redirect_to master_tree_url(@master_tree.id)
  end

  def show
    editors = []
    @master_tree.rosters.each do |roster|
      next if roster.user_id == current_user.id
      editors << { id: roster.user.id, email: roster.user.email, roles: roster.user.roles.map { |r| r.name.humanize }, status: "online" }
    end
    @master_tree.master_tree_contributors.each do |contributor|
      next if contributor.user_id == current_user.id
      editors << { id: contributor.user.id, email: contributor.user.email, roles: contributor.user.roles.map { |r| r.name.humanize }, status: "offline" } unless editors.any? { |h| h[:id] == contributor.user.id }
    end
    
    @editors = editors.sort_by { |h| h[:email] }
    
    message = { subject: "member-login", message: "", time: Time.new.to_s, user: { id: current_user.id, email: current_user.email, roles: current_user.roles.map { |r| r.name.humanize } } }.to_json
    Juggernaut.publish("tree_" + @master_tree.id.to_s, message)
  end

  def edit
  end

  def update
    if params[:cancel]
      redirect_to master_tree_url(params[:id])
    else
      params[:master_tree] ||= {}
      @master_tree.update_attributes(params[:master_tree].select{ |k,v| MasterTree.column_names.include?(k) }.permit!)
      if @master_tree.save
        if request.xhr?
          render json: { status: "OK"}
        else
          flash[:success] = "Working Tree successfully updated"
          render :edit
        end
      else
        render :edit
      end
    end
  end

  def destroy
    @deleted_tree = DeletedTree.find_by_master_tree_id(params[:id])
    if @master_tree.nuke && @deleted_tree.nuke
      flash[:notice] = 'Tree successfully deleted'
      redirect_to action: :index, status: :see_other
    end
  end

  def publish
    gp = GnaclrPublisher.create!(master_tree_id: params[:id].to_i)
    Resque.enqueue(GnaclrPublisher, gp.id)
    render json: { status: "OK" }
  end
  
  def undo
    action_command = UndoActionCommand.undo(params[:id], request.headers["X-Session-ID"]) 
    action = action_command.nil? ? { status: "Nothing to undo" } : action_command.serializable_hash(except: :json_message).merge({ json_message: JSON.parse(action_command.json_message, symbolize_keys: true) })
    render json: action
  end
  
  def redo
    action_command = RedoActionCommand.redo(params[:id], request.headers["X-Session-ID"]) 
    action = action_command.nil? ? { status: "Nothing to redo" } : action_command.serializable_hash(except: :json_message).merge({ json_message: JSON.parse(action_command.json_message, symbolize_keys: true) })
    render json: action
  end

end
