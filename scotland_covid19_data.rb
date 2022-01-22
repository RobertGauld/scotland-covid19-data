# frozen_string_literal: true

class ScotlandCovid19Data
  VERSION_FILE = 'ScotlandCovid19Data.version'
  HEALTH_BOARD_CASES_FILE = 'COVID19 - Daily Management Information - Scottish Health Boards - Cumulative cases.csv'
  INTENSIVE_CARE_FILE = 'COVID19 - Daily Management Information - Scottish Health Boards - ICU patients - Confirmed.csv'
  DECEASED_FILE = 'COVID19 - Daily Management Information - Scotland - Deaths.csv'
  HEALTH_BOARD_POPULATIONS_FILE = 'HB_Populations.csv'
  OLD_HEALTH_BOARD_CASES_FILE = 'regional_cases.csv'
  OLD_HEALTH_BOARD_DEATHS_FILE = 'regional_deaths.csv'
  OLD_INTENSIVE_CARE_FILE = 'intensive_care.csv'
  OLD_DECEASED_FILE = 'scot_test_positive_deceased.csv'
  DOWNLOAD_FILES = [
    HEALTH_BOARD_CASES_FILE,
    INTENSIVE_CARE_FILE,
    DECEASED_FILE,
  ].freeze

  def self.health_boards
    load_health_boards unless defined?(@@health_boards)
    @@health_boards
  end

  def self.health_board_scale
    load_health_boards unless defined?(@@health_board_scale)
    @@health_board_scale
  end

  def self.cases
    load_cases unless defined?(@@cases)
    @@cases
  end

  def self.deaths
    load_deaths unless defined?(@@deaths)
    @@deaths
  end

  def self.intensive_cares
    load_intensive_care unless defined?(@@intensive_cares)
    @@intensive_cares
  end

  def self.intensive_care
    load_intensive_care unless defined?(@@intensive_care)
    @@intensive_care
  end

  def self.deceased
    load_deceased unless defined?(@@deceased)
    @@deceased
  end

  def self.download(force: false, only: nil)
    $logger.info (force ? 'Downloading all' : 'Downloading new') + \
                 (only ? " #{only.inspect} data." : ' data.')
    force ||= update_available?
    files = only ? [*only] : DOWNLOAD_FILES

    files.each do |file|
      url = "https://raw.githubusercontent.com/DataScienceScotland/COVID-19-Management-Information/master/export/old-file-structure/#{file.gsub(' ', '%20')}"
      file = File.join(DATA_DIR, file)

      if !File.exist?(file) || force
        $logger.debug "#{url} => #{file}"
        src = URI(url).open
        File.open(file, 'w') do |dst|
          IO.copy_stream src, dst
        end
      end
    end

    unless only
      File.write(File.join(DATA_DIR, VERSION_FILE), github_latest_commit_sha)
    end
  end

  def self.load
    load_health_boards
    load_cases
    load_deaths
    load_intensive_care
    load_deceased
  end

  def self.update
    download
    load
  end

  def self.update_available?
    $logger.info 'Checking github for updated data'
    github_data_sha = github_latest_commit_sha
    $logger.debug "Current data: #{current_version}, " \
                  "Github data: #{github_data_sha}, " \
                  "Data is #{(github_data_sha == current_version) ? 'current' : 'stale'}."

    current_version != github_data_sha
  end

  def self.current_version
    return nil unless File.exist?(File.join(DATA_DIR, VERSION_FILE))

    File.read(File.join(DATA_DIR, VERSION_FILE))
  end

  class << self
    private

    def load_health_boards
      $logger.info "Reading health board data (#{HEALTH_BOARD_POPULATIONS_FILE})."
      unless File.exist?(File.join(DATA_DIR, HEALTH_BOARD_POPULATIONS_FILE))
        download(only: HEALTH_BOARD_POPULATIONS_FILE)
      end

      health_boards = []
      health_board_scale = { 'Grand Total' => 0 }
      CSV.read(File.join(DATA_DIR, HEALTH_BOARD_POPULATIONS_FILE), headers: true, converters: :numeric)
         .each { |record| health_boards.push record['Name'] unless health_boards.include? record['Name'] }
         .each { |record| health_board_scale[record['Name']] = record['Population'].to_f / NUMBERS_PER }
         .each { |record| health_board_scale['Grand Total'] += record['Population'].to_f / NUMBERS_PER }
      health_boards.delete 'Grand Total'
      @@health_boards = health_boards.sort
      @@health_board_scale = health_board_scale
      $logger.debug "Read #{health_boards.count} health boards."
    end

    def load_cases
      $logger.info "Reading cases data (#{HEALTH_BOARD_CASES_FILE})."
      unless File.exist?(File.join(DATA_DIR, HEALTH_BOARD_CASES_FILE))
        download(only: HEALTH_BOARD_CASES_FILE)
      end

      date_converter = ->(value, field) { field.header.eql?('Date') && value != 'Date' ? (value.eql?('NA') ? nil : Date.parse(value)) : value }
      number_converter = ->(value, field) { !['Date', nil].include?(field.header) ? ['X', '*', 'NA'].include?(value) ? nil : value.to_i / health_board_scale.fetch(field.header) : value }

      headers = ['Date', *health_boards, 'Grand Total']
      @@cases = CSV.read(File.join(DATA_DIR, OLD_HEALTH_BOARD_CASES_FILE), headers: headers, converters: [number_converter, date_converter])
                   .[](1..-1) # Skip the header row
                   .map { |record| [record['Date'], [*health_boards, 'Grand Total'].zip(record.values_at(*health_boards, 'Grand Total').map { _1.eql?('*') || _1.eql?('NA') ? nil : _1 }).to_h] }
                   .to_h

      CSV.read(File.join(DATA_DIR, HEALTH_BOARD_CASES_FILE), headers: headers, converters: [number_converter, date_converter])
         .[](1..-1) # Skip the header row
         .reject { |record| record.values_at(*health_boards).all?(:nil?) || record['Date'].nil? }
         .each do |record|
           record['Grand Total'] = record.values_at(*health_boards).reject { _1.nil? || _1 == '*' }.sum
           @@cases[record['Date']] = record.to_h
         end

      $logger.debug "Read cases data for #{@@cases.keys.sort.values_at(0, -1).map(&:to_s).join(' to ')}."
    end

    def load_deaths
      $logger.info "Reading deaths data (#{OLD_HEALTH_BOARD_DEATHS_FILE})."
      unless File.exist?(File.join(DATA_DIR, OLD_HEALTH_BOARD_DEATHS_FILE))
        download(only: OLD_HEALTH_BOARD_DEATHS_FILE)
      end

      date_converter = ->(value, field) { field.header.eql?('Date') ? (value.eql?('NA') ? nil : Date.parse(value)) : value }
      number_converter = ->(value, field) { !field.header.eql?('Date') ? value.eql?('X') ? nil : value.to_i / health_board_scale.fetch(field.header) : value }

      @@deaths = CSV.read(File.join(DATA_DIR, OLD_HEALTH_BOARD_DEATHS_FILE), headers: true, converters: [number_converter, date_converter])
                    .map { |record| record.to_h.transform_values! { |value| value.eql?('*') || value.eql?('NA') ? nil : value } }
                    .reject { |record| record.values_at(*health_boards).all?(:nil?) || record['Date'].nil? }
                    .map { |record| [record['Date'], [*health_boards, 'Grand Total'].zip(record.values_at(*health_boards, 'Grand Total')).to_h] }
                    .to_h
      $logger.debug "Read deaths data for #{@@deaths.keys.sort.values_at(0, -1).map(&:to_s).join(' to ')}."
    end

    def load_intensive_care
      $logger.info "Reading intensive care data (#{INTENSIVE_CARE_FILE})."
      unless File.exist?(File.join(DATA_DIR, INTENSIVE_CARE_FILE))
        download(only: INTENSIVE_CARE_FILE)
      end

      number_converter = ->(value, field) { !['Date', nil].include?(field.header) ? ['X', '*'].include?(value) ? nil : value.to_i : value }

      @@intensive_cares = {}

      @@intensive_care = CSV.read(File.join(DATA_DIR, OLD_INTENSIVE_CARE_FILE), headers: ['Date', 'Grand Total'])
                            .[](1..-1) # Skip the header row
                            .map { |record| record.to_h.transform_values! { |value| value.eql?('*') || value.eql?('NA') ? nil : value } }
                            .map { |record| [Date.parse(record['Date']), record['Grand Total']&.to_i] }
                            .to_h

      headers = ['Date', *health_boards, 'The Golden Jubilee National Hospital', 'Grand Total']
      CSV.read(File.join(DATA_DIR, INTENSIVE_CARE_FILE), headers: headers, converters: [number_converter])
         .[](1..-1) # Skip the header row
         .map { |record| record.to_h.transform_values! { |value| value.eql?('*') || value.eql?('NA') ? nil : value } }
         .each do |record|
           record['Grand Total'] = record.values[1..-1].map(&:to_i).sum
           @@intensive_cares[Date.parse(record['Date'])] = record
           @@intensive_care[Date.parse(record['Date'])] = record['Grand Total']&.to_i
         end

      $logger.debug "Read intensive care data for #{@@intensive_care.keys.sort.values_at(0, -1).map(&:to_s).join(' to ')}."
    end

    def load_deceased
      $logger.info "Reading deceased data (#{DECEASED_FILE})."
      unless File.exist?(File.join(DATA_DIR, DECEASED_FILE))
        download(only: DECEASED_FILE)
      end

      date_converter = ->(value, field) { field.header.eql?('Date') && value != 'Date' ? (value.eql?('NA') ? nil : Date.parse(value)) : value }

      headers = ['Date', 'Deceased']

      @@deceased = CSV.read(File.join(DATA_DIR, OLD_DECEASED_FILE), headers: headers, converters: [:numeric, date_converter])
                      .[](1..-1) # Skip the header row
                      .map { |record| record.to_h.transform_values! { |value| value.eql?('*') || value.eql?('NA') ? nil : value } }
                      .reject { |record| record['Date'].nil? }
                      .map { |record| [record['Date'], record['Deceased']] }
                      .to_h

      CSV.read(File.join(DATA_DIR, DECEASED_FILE), headers: headers, converters: [:numeric, date_converter])
         .[](1..-1) # Skip the header row
         .map { |record| record.to_h.transform_values! { |value| value.eql?('*') || value.eql?('NA') ? nil : value } }
         .reject { |record| record['Deceased'].nil? }
         .each { |record| @@deceased[record['Date']] = record['Deceased'] }


      $logger.debug "Read deceased data for #{@@deceased.keys.sort.values_at(0, -1).map(&:to_s).join(' to ')}."
    end

    def github_latest_commit_sha
      JSON.parse(URI('https://api.github.com/repos/DataScienceScotland/COVID-19-Management-Information/commits/master').read)['sha']
    end
  end
end
