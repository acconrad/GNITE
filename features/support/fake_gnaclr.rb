require 'sham_rack'
require 'sinatra'
require 'builder'

module FakeGnaclr
  class App < Sinatra::Base
    get '/classifications' do
      xml = {
        :classifications => Store.all.map do |classification|
          classification.attributes
        end
      }.to_xml
    end
  end

  class Store
    cattr_accessor :classifications
    @@classifications = []

    def self.all
      @@classifications
    end

    def self.clear!
      @@classifications = []
    end

    def self.insert(*hashes)
      hashes.each do |hash|
        if hash['file_url']
          hash['file_url'] = 'file:///' + Rails.root.join('features/support/fixtures', hash['file_url']).to_s
        end

        extract_author_list(hash)
        @@classifications.push(GnaclrClassification.new(hash))
      end
    end

    def self.insert_revision_for_classification_title(opts)
      revision_attributes  = opts[:revision_attributes]
      classification_title = opts[:classification_title]
      classification = @@classifications.detect { |c| c.title == classification_title }
      classification.add_revision_from_attributes(revision_attributes)
    end

    private

    def self.extract_author_list(hash)
      author_list = hash.delete('author_list')

      hash['authors'] = author_list.split(", ").map do |author_string|
        first_name, last_name, email = author_string.split(/[ <>]+/)

        {
          'first_name' => first_name,
          'last_name'  => last_name,
          'email'      => email
        }
      end
    end
  end
end

ShamRack.at(GnaclrClassification::URL).rackup do
  run FakeGnaclr::App
end

Before do
  FakeGnaclr::Store.clear!
end
