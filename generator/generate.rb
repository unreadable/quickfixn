$LOAD_PATH << File.dirname(__FILE__)

require 'rubygems'
require 'fix_dictionary'
require 'fields_gen'
require 'messages_gen'
require 'proj_gen'
require 'message_factory_gen'

class Generator  
  def self.generate
    generator = Generator.new
    generator.generate_csproj
    generator.generate_message_factories
    generator.generate_fields
    generator.generate_messages
  end
  
  def initialize
    @fix44 = FIXDictionary.load spec('FIX44')
    @qfSpecific = FIXDictionary.load spec('QuickFixSpecificMessages')
    @src_path = File.join File.dirname(__FILE__), '..', 'QuickFIXn'
  end

  def spec fixver
    File.join File.dirname(__FILE__), "..", "spec", "fix", "#{fixver}.xml"
  end
    
  def generate_fields
    fields_path = File.join(@src_path, 'Fields', 'Fields.cs')
    tags_path = File.join(@src_path, 'Fields', 'FieldTags.cs')
    FieldGen.generate(agg_fields, fields_path, tags_path)
  end

  def agg_fields
    field_names = (@qfSpecific.fields.keys + @fix44.fields.keys).uniq
    field_names.map {|fn| get_field_def(fn) }
  end

  def get_field_def fld_name
    # we give priority to latest fix version
    fld = merge_field_defs(
      @qfSpecific.fields[fld_name],
      @fix44.fields[fld_name]
    )
    
    raise "couldn't find field! #{fld}" if fld.nil?
    fld
  end

  def merge_field_defs *alldefs
    defs = alldefs.reject {|d| d.nil?}
    return nil if defs.empty?
    fld = defs.first
    
    vals = defs.map { |d| d[:values] }.reject { |d| d.nil? }.flatten
    return fld if vals.empty?
    vals = vals.inject([]) {|saved, v| saved << v unless saved.detect {|u| u[:desc] == v[:desc]}; saved}
    fld[:values] = vals
    fld
  end

  def generate_messages
    msgs_path = File.join(@src_path, 'Message')
    MessageGen.generate(@fix44.messages,  msgs_path, 'FIX44')
    #MessageGen.generate(@qfSpecific.messages,  msgs_path, 'QuickFixSpecific')
  end

  def generate_csproj
    csproj_path = File.join(@src_path, 'FixMessages.csproj')
    CSProjGen.generate(
      csproj_path,
      [
        {:version=>'FIX44', :messages=>@fix44.messages},
        #{:version=>'QuickFixSpecific', :messages=>@qfSpecific.messages},
      ]
    )
  end

  def generate_message_factories
    msgs_path = File.join(@src_path, 'Message')
    MessageFactoryGen.generate(@fix44.messages,  msgs_path, 'FIX44')
    #MessageFactoryGen.generate(@qfSpecific.messages,  msgs_path, 'QuickFixSpecific')
  end
end


Generator.generate
