#!/usr/bin/env ruby
#
# json-csv
#
# Converts JSON to CSV, and vice versa.
# Run "json-csv -h" to see options.
#
# Copyright 2017 Appcues, Inc.
# https://github.com/appcues/json-csv
#
# This code is released under the MIT License, available at:
# https://opensource.org/licenses/MIT
#
require 'optparse'
require 'json'

class JsonCsv
  VERSION = "0.5.0"
  VERSION_DATE = "2017-06-25"

  DEFAULT_OPTS = {
    input_file: "-",
    output_file: "-",
    source_encoding: "json",
    tmpdir: ENV['TMPDIR'] || "/tmp",
    debug: false,
    depth: -1,
    line_ending: "\r\n",
  }

  class << self
    def new_from_argv(argv)
      opts = DEFAULT_OPTS

      OptionParser.new do |op|
        op.banner = <<-EOT
      Converts JSON to CSV, and vice versa.
      Usage: #{$0} [options] [--] [input-file [output-file]]
        EOT

        op.on("-i input-file", "--input input-file", "Input file (default STDIN)") do |input_file|
          opts[:input_file] = input_file
        end

        op.on("-o output-file", "--output output-file", "Output file (default STDOUT)") do |output_file|
          opts[:output_file] = output_file
        end

        op.on("-s json|csv", "--source-encoding json|csv", "Encoding of input file (default json)") do |source|
          opts[:source_encoding] = source
        end

        op.on("-d depth", "--depth depth", "Maximum depth of JSON-to-CSV conversion (default -1, unlimited)") do |depth|
          opts[:depth] = depth.to_i
          opts[:depth] += 1 if opts[:depth] > 0  # this is a fudge to use -1 as infinity
        end

        op.on("-e crlf|cr|lf", "--line-ending crlf|cr|lf", "Line endings for output file (default crlf).") do |ending|
          opts[:line_ending] = {"crlf" => "\r\n", "cr" => "\r", "lf" => "\n"}[ending]
          if !opts[:line_ending]
            STDERR.puts "Invalid line ending '#{ending}'.  Valid choices: crlf cr lf"
            exit 1
          end
        end

        op.on_tail("--debug", "Turn debugging messages on") do
          opts[:debug] = true
        end

        op.on_tail("--version", "Print version info and exit") do
          puts "json-csv version #{VERSION} (#{VERSION_DATE})"
          puts "https://github.com/appcues/json-csv"
          exit
        end

        op.on_tail("-h", "--help", "Show this message and exit") do
          puts op.to_s
          exit
        end

      end.parse!(argv)


      opts[:input_file] = argv.shift if argv.count > 0
      opts[:output_file] = argv.shift if argv.count > 0

      self.new(opts)
    end

    def convert_json_to_csv(opts)
      self.new(opts).convert_json_to_csv()
    end

    def convert_csv_to_json(opts)
      self.new(opts).convert_csv_to_json()
    end
  end

  def initialize(opts)
    @opts = DEFAULT_OPTS.merge(opts)
  end

  def run(opts = {})
    opts = @opts.merge(opts)
    enc = opts[:source_encoding]
    if enc == "json"
      convert_json_to_csv()
    elsif enc == "csv"
      convert_csv_to_json()
    else
      STDERR.puts "no such source encoding '#{enc}'"
      exit 1
    end
  end

  def convert_json_to_csv(opts = {})
    opts = @opts.merge(opts)

    ## First pass -- create CSV headers from JSON input
    input_fh = nil
    tmp_fh = nil
    tmp_filename = nil
    data_filename = nil

    if opts[:input_file] == "-"
      input_fh = STDIN
      data_filename = tmp_filename = "#{opts[:tmpdir]}/json-csv-#{$$}.tmp"
      debug(opts, "STDIN will be written to #{tmp_filename}.")
      tmp_fh = File.open(data_filename, "w")
    else
      input_fh = File.open(opts[:input_file], "r")
      data_filename = opts[:input_file]
    end

    debug(opts, "Getting headers from JSON data.")
    headers = get_headers_from_json(input_fh, tmp_fh, opts[:depth])

    input_fh.close
    tmp_fh.close if tmp_fh


    ## Second pass -- write CSV data from JSON input
    data_fh = File.open(data_filename, "r")
    output_fh = nil

    if opts[:output_file] == "-"
      output_fh = STDOUT
    else
      output_fh = File.open(opts[:output_file], "w")
    end

    debug(opts, "Writing CSV output.")
    output_csv(headers, data_fh, output_fh)
    data_fh.close
    output_fh.close

    debug(opts, "Removing #{tmp_filename}.")
    File.unlink(tmp_filename) if tmp_filename
  end

  def convert_csv_to_json(opts = {})
    raise NotImplementedError
  end


private

  def debug(opts, msg)
    STDERR.puts("#{Time.now}\t#{msg}") if opts[:debug]
  end

  # Returns a hash of `'header' => index` pairs, sorted.
  def get_headers_from_json(input_fh, tmp_fh, depth)
    headers = {}
    input_fh.each_line do |input|
      tmp_fh.puts(input) if tmp_fh
      json = JSON.parse(input)
      flatten_json(json, depth).each do |key, value|
        headers[key] = true
      end
    end
    sort_keys(headers)
  end

  # Sorts a hash with string keys by number of dots in the string,
  # then alphabetically.
  # Returns a hash of `'key' => index` pairs, in order of index.
  def sort_keys(hash)
    sorted = {}
    sorted_keys = hash.keys.sort do |a, b|
      x = (count_dots(a) <=> count_dots(b))
      x == 0 ? (a<=>b) : x
    end
    sorted_keys.each_with_index do |key, i|
      sorted[key] = i
    end
    sorted
  end

  def count_dots(str)
    str.chars.select{|c| c == "."}.count
  end

  def flat_assign(dest, key, value, depth)
    flat_value = flatten_json(value, depth - 1)
    if flat_value.is_a?(Hash)
      flat_value.each do |k,v|
        dest["#{key}.#{k}"] = v
      end
    else
      dest["#{key}"] = flat_value
    end
    dest
  end

  def flatten_json(json, depth = -1)
    return {} if depth == 0

    if json.is_a?(Hash)
      flat = {}
      json.each do |key, value|
        flat_assign(flat, key, value, depth)
      end
      flat

    elsif json.is_a?(Array)
      flat = {}
      json.each_with_index do |value, i|
        flat_assign(flat, i, value, depth)
      end
      flat

    else # number or string
      json
    end
  end

  def armor(val)
    str = val.to_s.gsub('"', '""')
    if str.match(/[",\n]/)
      '"' + str + '"'
    else
      str
    end
  end

  def output_csv(headers, data_fh, output_fh, line_ending)
    # Write header line
    output_fh.write(headers.map{|h| armor(h[0])}.join(","))
    output_fh.write(line_ending)

    header_count = headers.count
    data_fh.each_line do |input|
      json = JSON.parse(input)
      flat = flatten_json(json)
      output = Array.new(header_count)
      flat.each do |key, value|
        output[headers[key]] = value if headers[key]
      end
      output_fh.write(output.map{|x| armor(x)}.join(","))
      output_fh.write(line_ending)
    end
  end
end


## command line mode
JsonCsv.new_from_argv(ARGV).run if $0 == __FILE__

