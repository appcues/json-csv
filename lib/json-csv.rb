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
  VERSION = "0.6.0"
  VERSION_DATE = "2017-06-29"

  DEFAULT_OPTS = {
    input_file: "-",
    output_file: "-",
    source_encoding: "json",
    tmpdir: ENV['TMPDIR'] || "/tmp",
    debug: false,
    depth: -1,
    line_ending: "\r\n",
    csv_delimiter: ",",
    columns: [],
    first_columns: [],
    exclude_columns: [],
  }

  class << self
    def parse_argv(argv)
      opts = DEFAULT_OPTS

      argv = OptionParser.new do |op|
        op.banner = <<-EOT
Converts JSON to CSV, and vice versa.
Usage: #{$0} [options] [--] [input-file [output-file]]
        EOT

        op.on("-i input-file", "--input input-file", "Input file (default '-', STDIN)") do |input_file|
          opts[:input_file] = input_file
        end

        op.on("-o output-file", "--output output-file", "Output file (default '-', STDOUT)") do |output_file|
          opts[:output_file] = output_file
        end

        op.on("-s json|csv", "--source-encoding json|csv", "Encoding of input file (default 'json')") do |source|
          opts[:source_encoding] = source.downcase
        end

        op.on("-d depth", "--depth depth", "Maximum depth of JSON-to-CSV conversion (default -1, unlimited)") do |depth|
          opts[:depth] = depth.to_i
        end

        op.on("-c column1,column2,...", "--columns column1,column2,...", "Don't scan JSON input for CSV columns; use these instead. Subsequent use of this option adds to the list of columns") do |columns|
          columns.split(",").each{|c| opts[:columns].push(c)}
        end

        op.on("-f column1,column2,...", "--first-columns column1,column2,...", "Columns to appear first (leftmost) in CSV output") do |columns|
          columns.split(",").each{|c| opts[:first_columns].push(c)}
        end

        op.on("-X column1,column2,...", "--exclude-columns column1,column2,...", "Columns to exclude from CSV output") do |columns|
          columns.split(",").each{|c| opts[:exclude_columns].push(c)}
        end

        op.on("-T tmpdir", "--tmpdir tmpdir", "Temporary directory (default $TMPDIR or '/tmp')") do |tmpdir|
          opts[:tmpdir] = tmpdir
        end

        op.on("-c delimiter", "--csv-delimiter delimiter", "Delimiter for CSV fields (default ',')") do |delimiter|
          opts[:csv_delimiter] = delimiter.gsub('\t', "\t")
        end

        op.on("-e crlf|cr|lf", "--line-ending crlf|cr|lf", "Line endings for output file (default 'crlf').") do |ending|
          opts[:line_ending] = {"crlf" => "\r\n", "cr" => "\r", "lf" => "\n"}[ending.downcase]
          if !opts[:line_ending]
            STDERR.puts "Invalid line ending '#{ending}'.  Valid choices: crlf cr lf"
            exit 1
          end
        end

        op.on("--debug", "Turn debugging messages on") do
          opts[:debug] = true
        end

        op.on("--version", "Print version info and exit") do
          puts "json-csv version #{VERSION} (#{VERSION_DATE})"
          puts "https://github.com/appcues/json-csv"
          exit
        end

        op.on("-h", "--help", "Show this message and exit") do
          puts op.to_s
          exit
        end

      end.parse(argv)

      opts[:input_file] = argv.shift if argv.count > 0
      opts[:output_file] = argv.shift if argv.count > 0

      opts
    end

    def new_from_argv(argv)
      opts = parse_argv(argv)
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


  # Performs the JSON-to-CSV or CSV-to-JSON conversion, as specified in
  # `opts` and the options passed in during `JsonCsv.new`.
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

    ## First pass -- Create CSV headers
    input_fh = nil
    tmp_fh = nil
    data_fh = nil
    tmp_filename = nil
    data_filename = nil
    headers = {}

    depth = opts[:depth]
    depth += 1 if depth > 0  # a fudge, in order to use -1 as infinity

    if opts[:input_file] == "-"
      if opts[:columns].count == 0
        # Scan input for headers
        input_fh = STDIN
        data_filename = tmp_filename = "#{opts[:tmpdir]}/json-csv-#{$$}.tmp"
        debug(opts, "STDIN will be written to #{tmp_filename}.")
        tmp_fh = File.open(data_filename, "w")
      else
        data_fh = STDIN
      end
    else
      input_fh = File.open(opts[:input_file], "r")
      data_filename = opts[:input_file]
    end

    begin
      if opts[:columns].count > 0
        opts[:columns].each_with_index{|c,i| headers[c]=i}
      else
        debug(opts, "Getting headers from JSON data.")
        headers = get_headers_from_json(input_fh, tmp_fh, depth, opts[:first_columns], opts[:exclude_columns])
      end
    ensure
      input_fh.close if input_fh
      tmp_fh.close if tmp_fh
    end


    ## Second pass -- write CSV data from JSON input
    data_fh ||= File.open(data_filename, "r")
    output_fh = nil

    if opts[:output_file] == "-"
      output_fh = STDOUT
    else
      output_fh = File.open(opts[:output_file], "w")
    end

    begin
      debug(opts, "Writing CSV output.")
      output_csv(headers, data_fh, output_fh, opts[:line_ending], opts[:csv_delimiter])
    ensure
      data_fh.close
      output_fh.close
      File.unlink(tmp_filename) if tmp_filename
      debug(opts, "Removed #{tmp_filename}.") if tmp_filename
    end
  end

  def convert_csv_to_json(opts = {})
    STDERR.puts "CSV-to-JSON conversion is not yet implemented."
    exit 99
  end


private

  def debug(opts, msg)
    STDERR.puts("#{Time.now}\t#{msg}") if opts[:debug]
  end



  # Scans a JSON file at `input_fh` to determine the headers
  # to use when writing CSV data.
  # Returns a hash of `'header' => index` pairs, sorted.
  def get_headers_from_json(input_fh, tmp_fh, depth, first_columns, exclude_columns)
    headers = {}
    input_fh.each_line do |input|
      tmp_fh.puts(input) if tmp_fh
      json = JSON.parse(input)
      flatten_json(json, depth).each do |key, value|
        headers[key] = true
      end
    end
    exclude_columns.each {|col| headers.delete(col)}
    sort_keys(headers, first_columns)
  end

  # Helper function to get_headers_from_json --
  # Sorts a hash with string keys by number of dots in the string,
  # then alphabetically.
  # Returns a hash of `'key' => index` pairs, in order of index.
  def sort_keys(hash, first_columns = [])
    first_columns_hash = Hash.new(2**32)
    first_columns.each_with_index {|col, i| first_columns_hash[col] = i}

    sorted_keys = hash.keys.sort {|a,b| key_sort_fn(a, b, first_columns_hash)}

    sorted = {}
    sorted_keys.each_with_index {|key, i| sorted[key] = i}

    sorted
  end

  def key_sort_fn(a, b, first_columns_hash)
    x = (first_columns_hash[a] <=> first_columns_hash[b])
    return x unless x==0

    x = (count_dots(a) <=> count_dots(b))
    return x unless x==0

    a <=> b
  end

  # Helper function to sort_keys --
  # Counts the number of dots in a string.
  def count_dots(str)
    str.chars.select{|c| c == "."}.count
  end



  # Returns a flattened representation of the given JSON-encodable
  # data (that is: hashes, arrays, numbers, strings, and `nil`).
  # Dot-separated string keys are used to encode nested hash and
  # array structures.
  #
  # Hashes get flattened like so:
  #
  #     flatten_json({a: {b: {c: 1, d: "x"}, c: nil}})
  #     #=> {"a.b.c" => 1, "a.b.d" => "x", "a.c" => nil}
  #
  # Arrays are turned into hashes like:
  #
  #     flatten_json([0, 1, 2, {a: "x"])
  #     #=> {"0" => 0, "1" => 1, "2" => 2, "3.a" => "x"}
  #
  # Simple data (numbers, strings, nil) passes through unchanged.
  #
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

    else # number or string or nil
      json
    end
  end

  ## Helper function to flatten_json --
  ## Assigns a flattened value at the current key.
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



  ## Reads JSON data from data_fh, and writes CSV data (with header) to
  ## output_fh.
  def output_csv(headers, data_fh, output_fh, line_ending, delimiter)
    output_fh.write(headers.map{|h| csv_armor(h[0], delimiter)}.join(delimiter))
    output_fh.write(line_ending)

    header_count = headers.count
    data_fh.each_line do |input|
      json = JSON.parse(input)
      flat = flatten_json(json)
      output = Array.new(header_count)
      flat.each do |key, value|
        output[headers[key]] = value if headers[key]
      end
      output_fh.write(output.map{|x| csv_armor(x, delimiter)}.join(delimiter))
      output_fh.write(line_ending)
    end
  end

  ## Helper function to output_csv --
  ## Returns a CSV-armored version of `val`.
  ## Escapes special characters and adds double-quotes if necessary.
  def csv_armor(val, delimiter)
    str = val.to_s.gsub('"', '""')
    if str.index('"') || str.index("\n") || str.index(delimiter)
      '"' + str + '"'
    else
      str
    end
  end
end


## command line mode
JsonCsv.new_from_argv(ARGV).run if $0 == __FILE__

