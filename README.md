# json-csv

A command-line utility and Ruby gem for converting JSON files to CSV,
and CSV files to JSON (soon).


## Install it

You can install json-csv as a Ruby Gem:

    gem imstall json-csv

Or as a standalone command-line script:

    # Systemwide install
    sudo curl https://raw.githubusercontent.com/appcues/json-csv/master/lib/json_csv.rb > /usr/local/bin/json-csv
    sudo chmod a+x /usr/local/bin/json-csv

    # Single-user install
    curl https://raw.githubusercontent.com/appcues/json-csv/master/lib/json_csv.rb > json-csv
    chmod a+x json-csv

Run `json-csv -h` to see execution options.


## Why json-csv?

* Customizable: Max nested data depth, line endings, etc

* CSV output is sorted by depth and alphabet

* Zero dependencies outside core Ruby 2.x

* Easy install


## Authorship and License

json-csv is copyright 2017, Appcues, Inc.

This code is released under the
[https://opensource.org/licenses/MIT](MIT License).

