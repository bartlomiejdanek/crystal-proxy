require "http/server"
require "http/client"
require "http/params"
require "option_parser"
require "yaml"
require "uri"

port = ""
OptionParser.parse! do |parser|
  parser.on("-port", "--port=PORT", "Used PORT") { |uport| port = uport }
end

skip_headers = [
  "Accept-Encoding",
  "Accept-Language",
  "Connection",
  "Content-Encoding",
  "Content-Length",
  "Cookie",
  "Host",
  "Transfer-Encoding",
  "Version",
  "X-Forwarded-For",
  "X-Forwarded-Port",
  "X-Forwarded-Proto"
]

mappings = YAML.parse(File.read("mappings.yml"))["mappings"]

server = HTTP::Server.new(
  port.to_i,
  [
    HTTP::ErrorHandler.new,
    HTTP::LogHandler.new,
  ]
) do |context|
  request_mapping = context.request.path.split("/")[1]

  mapping = mappings.find do |mapping|
    mapping["path"] == "/#{request_mapping}"
  end

  if mapping
    url = mapping["host"].to_s + context.request.path.to_s.gsub(mapping["path"].to_s, "")
    uri = URI.parse(url)
    uri.query = context.request.query_params.to_s

    HTTP::Client.get(uri) do |response|
      context.response.content_type = response.content_type.to_s
      context.response.status_code = response.status_code
      response.headers.each do |k, v|
        next if skip_headers.includes?(k)
        context.response.headers[k] = v
      end
      context.response.print response.body_io.gets_to_end
    end
  else
    context.response.content_type = "text/plain"
    context.response.print "invalid mapping"
  end
end

begin
  puts "Listening on http://127.0.0.1:#{port}"
  server.listen
rescue ex
  puts ex.message
  puts ex.backtrace
end
