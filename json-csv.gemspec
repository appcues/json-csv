require './lib/json-csv'

Gem::Specification.new do |s|
  s.name        = 'json-csv'
  s.version     = JsonCsv::VERSION
  s.date        = JsonCsv::VERSION_DATE
  s.summary     = "A command-line JSON/CSV converter"
  s.authors     = ["pete gamache"]
  s.email       = 'pete@appcues.com'
  s.files       = ["lib/json-csv.rb"]
  s.homepage    = 'http://github.com/appcues/json-csv'
  s.license     = 'MIT'
  s.executables << 'json-csv'
end

