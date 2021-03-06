require "rapture"
require "sequel"
require "yaml"
require "yard"

config = YAML.load_file('config.yml')

TOKEN = config["token"]
OWNER_ID = config["owner_id"].to_i
GITHUB_PAGES_URL = config["docs_url"]
LIB_DIR = config["lib"]["dir"]
ROOT_NAMESPACE = config["lib"]["namespace"]

YARD::Registry.load_yardoc

DB = Sequel.connect("sqlite://doc-o-tron.db")

DB.create_table? :allowed_channels do
  String :id
end

def format_path(object)
  url_path = if object.type == :method
               namespace, method_name = object.path.split('#')
               "#{namespace.gsub("::", "/")}.html##{method_name}-instance_method"
             elsif object.type == :constant
               *namespace, const =  object.path.split('::')
               "#{namespace.join("/")}.html##{const}-constant"
             else
               object.path.gsub("::", "/") + ".html"
             end
  url_path.gsub("?", "%3F")
end

client = Rapture::Client.new(TOKEN)

# Allow/Deny/Update
client.on_message_create do |message|
  next unless message.author.id == OWNER_ID

  case message.content
  when "doc-o-tron>allow"
    DB[:allowed_channels].insert(message.channel_id.to_s)
    client.create_message(message.channel_id, content: "Success")
  when  message.content == "doc-o-tron>deny"
    DB[:allowed_channels].where(id: message.channel_id.to_s).delete
    client.create_message(message.channel_id, content: "Success")
  when "doc-o-tron>update"
    client.create_message(message.channel_id, content: "Updating sources")
    `git pull --recurse-submodules`
    `bundle exec yard doc #{LIB_DIR}`
    YARD::Registry.load_yardoc
  end
end

client.on_message_create do |message|
  next unless DB[:allowed_channels].map(:id).include? message.channel_id.to_s

  args = message.content.split('>', 2)
  if args[0] == 'doc' && args[1]
    object = YARD::Registry.load_yardoc.resolve(P(ROOT_NAMESPACE), args.last.strip, true)

    if object
      path = format_path(object)

      fields = []
      fields << {
        name: "Parameters",
        value: object.tags("param").collect {|param| "`#{param.name} [#{param.types.join ", "}] #{param.text}`" }.join("\n")
      } unless object.tags("param").empty?

      fields << {
        name: "Options",
        value: object.tags("option").collect {|o| "`#{o.name}{#{o.pair.name}} [#{o.pair.types.join(", ")}] #{o.pair.text}`" }.join("\n")
      } unless object.tags("option").empty?

      fields << {
        name: "Return",
        value: object.tags("return").collect {|o| "`[#{o.types.join(", ")}] #{o.text}`" }.join("\n")
      } unless object.tags("return").empty?

      client.create_message(
        message.channel_id,
        embed: {
          title: object.path,
          url: "#{GITHUB_PAGES_URL}/#{path}",
          description: object.docstring,
          fields: fields
        }
      )
    else
      client.create_message(
        message.channel_id,
        content: "Unable to find docs"
      )
    end
  end
end

client.run