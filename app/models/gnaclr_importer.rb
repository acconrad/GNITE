# encoding: utf-8
class GnaclrImporter < ActiveRecord::Base
  belongs_to :reference_tree

  unless defined? GNACLR_IMPORTER_DEFINED
    NAME_BATCH_SIZE = 10_000
    GNACLR_IMPORTER_DEFINED = true
  end
  @queue = :gnaclr_importer

  attr_reader   :darwin_core_data, :name_strings, :tree

  def self.perform(gnaclr_importer_id)
    gi = GnaclrImporter.find(gnaclr_importer_id)
    gi.import
  end

  def import
    begin
      fetch_tarball
      read_tarball
      store_tree
      activate_tree
    rescue RuntimeError => e
      DarwinCore.logger_write(@dwc.object_id, "Import Failed: %s" % e)
    end
  end

  def fetch_tarball
    if url.match(/^\s*http:\/\//)
      dlr = Gnite::Downloader.new(url, tarball_path)
      downloaded_length = dlr.download_with_percentage do |r|
        msg = sprintf("Downloaded %.0f%% in %.0f seconds ETA is %.0f seconds", r[:percentage], r[:elapsed_time], r[:eta])
        JobsLog.create(job_type: "GnaclrImporter", tree_id: self.reference_tree_id, message: msg)
      end
      JobsLog.create(job_type: "GnaclrImporter", tree_id: self.reference_tree_id, message: "Download finished, Size: %s" % downloaded_length)
    else
      Kernel.system("curl -s #{url} > #{tarball_path}")
    end
  end

  def read_tarball
    @dwc               = DarwinCore.new(tarball_path)
    DarwinCore.logger.subscribe(an_object_id: @dwc.object_id, tree_id: self.reference_tree_id, job_type: 'GnaclrImporter')
    normalizer        = DarwinCore::ClassificationNormalizer.new(@dwc)
    @darwin_core_data = normalizer.normalize
    @tree             = normalizer.tree
    @name_strings     = normalizer.name_strings + normalizer.vernacular_name_strings
    @languages        = {}
  end

  def store_tree
    DarwinCore.logger_write(@dwc.object_id, "Populating local database")
    DarwinCore.logger_write(@dwc.object_id, "Processing name strings")
    count = 0
    name_strings.in_groups_of(NAME_BATCH_SIZE).each do |group|
      count += NAME_BATCH_SIZE
      group = group.compact.collect do |name_string|
        Name.connection.quote(name_string).force_encoding('utf-8')
      end.join('), (')

      Name.transaction do
        Name.connection.execute "INSERT IGNORE INTO names (name_string) VALUES (#{group})"
      end
      DarwinCore.logger_write(@dwc.object_id, "Traversed %s scientific name strings" % count)
    end
    @nodes_count = 0
    build_tree(tree)
    DarwinCore.logger_write(@dwc.object_id, "Adding synonyms and vernacular names")
    insert_synonyms_and_vernacular_names
  end

  def build_tree(root, parent_id = reference_tree.root.id)
    taxon_ids = root.keys
    taxon_ids.each do |taxon_id|
      
      @nodes_count += 1
      DarwinCore.logger_write(@dwc.object_id, "Inserting %s records into database" % @nodes_count) if @nodes_count % 10000 == 0
      next unless taxon_id && darwin_core_data[taxon_id]

      local_id_sql   = Name.connection.quote(taxon_id).force_encoding('utf-8')
      name_sql       = Name.connection.quote(darwin_core_data[taxon_id].current_name).force_encoding('utf-8')
      rank_sql       = Node.connection.quote(darwin_core_data[taxon_id].rank).force_encoding('utf-8')
      parent_id ||= 'NULL'

      node_id = Node.connection.insert("INSERT IGNORE INTO nodes (local_id, name_id, tree_id, parent_id, rank) \
                    VALUES (#{local_id_sql}, (SELECT id FROM names WHERE name_string = #{name_sql} LIMIT 1), \
                                       #{reference_tree.id}, #{parent_id}, #{rank_sql})")
      add_synonyms_and_vernacular_names(node_id, taxon_id)
      build_tree(root[taxon_id], node_id)
    end
  end

  def activate_tree
    ReferenceTree.where(id: reference_tree.id).update_all(state: "active")
    DarwinCore.logger_write(@dwc.object_id, "Import is successful")
  end

  private

  def add_synonyms_and_vernacular_names(node_id, taxon_id)
    (@synonyms ||= []) << [node_id, darwin_core_data[taxon_id].synonyms]
    (@vernacular_names ||= []) << [node_id, darwin_core_data[taxon_id].vernacular_names]
  end

  def insert_synonyms_and_vernacular_names
    count = 0
    tables = { 'synonyms' => @synonyms, 'vernacular_names' => @vernacular_names }
    tables.each do |table, data|
      fields = 'status'
      if table == 'vernacular_names'
        fields = 'language_id, locality' 
      end
      next if data.blank?
      data.each do |node_id, objects|

        objects.each do |obj|
          name = obj.name
          values = nil
          if table == 'synonyms'
            values = Node.connection.quote(obj.status)
          else
            locality = Node.connection.quote(obj.locality) rescue "null"
            language_id = find_language(obj.language)
            values = "#{language_id}, #{locality}"
          end
          count += 1
          DarwinCore.logger_write(@dwc.object_id, "Added %s synonyms and vernacular names" % count) if count % 10000 == 0
          name_sql = Name.connection.quote(obj.name)
          Name.connection.execute "INSERT IGNORE INTO #{table} (node_id, name_id, #{fields}) VALUES (#{node_id.to_i}, (SELECT id FROM names WHERE name_string = #{name_sql} LIMIT 1), #{values})"
        end
      end
    end
  end

  def tarball_path
    Rails.root.join('tmp', reference_tree.id.to_s).to_s
  end

  def find_language(language_code)
    return 'NULL' unless language_code
    unless @languages[language_code]
      language_id = Language.find_by_iso_639_1(language_code).id rescue 'NULL'
      @languages[language_code] = language_id ? language_id : 'NULL'
    end
    @languages[language_code]
  end
  
end
