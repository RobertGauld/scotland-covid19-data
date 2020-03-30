# frozen_string_literal: true

class ScotlandCovid19Data
  HEALTH_BOARD_POPULATIONS_FILE = 'HB_Populations.csv'
  HEALTH_BOARD_CASES_FILE = 'regional_cases.csv'
  HEALTH_BOARD_DEATHS_FILE = 'regional_deaths.csv'

  @@current_git_sha = ''

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

  def self.download(force: false, only: nil)
    $logger.info (force ? 'Downloading all' : 'Downloading new') + \
                 (only ? " #{only.inspect} data." : ' data.')
    force ||= update_available?
    files = only ? [*only] : [HEALTH_BOARD_POPULATIONS_FILE, HEALTH_BOARD_CASES_FILE, HEALTH_BOARD_DEATHS_FILE]

    files.each do |file|
      url = "https://raw.githubusercontent.com/watty62/Scot_covid19/master/data/processed/#{file}"
      file = File.join(DATA_DIR, file)

      if !File.exist?(file) || force
        $logger.debug "#{url} => #{file}"
        src = URI(url).open
        File.open(file, 'w') do |dst|
          IO.copy_stream src, dst
        end
      end
    end

    @@current_git_sha = github_latest_commit_sha
  end

  def self.load
    load_health_boards
    load_cases
    load_deaths
  end

  def self.update
    download
    load
  end

  def self.update_available?
    $logger.info 'Checking github for updated data'
    github_data_sha = github_latest_commit_sha
    $logger.debug "Current data: #{@@current_git_sha}, " \
                  "Github data: #{github_data_sha}, " \
                  "Data is #{(github_data_sha == @@current_git_sha) ? 'current' : 'stale'}."

    @@current_git_sha != github_data_sha
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

      date_converter = ->(value, field) { field.header.eql?('Date') ? Date.parse(value) : value }
      number_converter = ->(value, field) { !field.header.eql?('Date') ? value.eql?('X') ? nil : value.to_i / health_board_scale.fetch(field.header) : value }

      @@cases = CSV.read(File.join(DATA_DIR, HEALTH_BOARD_CASES_FILE), headers: true, converters: [number_converter, date_converter])
                 .map { |record| [record['Date'], [*health_boards, 'Grand Total'].zip(record.values_at(*health_boards, 'Grand Total')).to_h] }
                 .to_h
      $logger.debug "Read cases data for #{@@cases.keys.sort.values_at(0, -1).map(&:to_s).join(' to ')}."
    end

    def load_deaths
      $logger.info "Reading deaths data (#{HEALTH_BOARD_DEATHS_FILE})."
      unless File.exist?(File.join(DATA_DIR, HEALTH_BOARD_DEATHS_FILE))
        download(only: HEALTH_BOARD_DEATHS_FILE)
      end

      date_converter = ->(value, field) { field.header.eql?('Date') ? Date.parse(value) : value }
      number_converter = ->(value, field) { !field.header.eql?('Date') ? value.eql?('X') ? nil : value.to_i / health_board_scale.fetch(field.header) : value }

      @@deaths = CSV.read(File.join(DATA_DIR, HEALTH_BOARD_DEATHS_FILE), headers: true, converters: [number_converter, date_converter])
                  .map { |record| [record['Date'], [*health_boards, 'Grand Total'].zip(record.values_at(*health_boards, 'Grand Total')).to_h] }
                  .to_h
      $logger.debug "Read deaths data for #{@@deaths.keys.sort.values_at(0, -1).map(&:to_s).join(' to ')}."    
    end

    def github_latest_commit_sha
      JSON.parse(URI('https://api.github.com/repos/watty62/Scot_covid19/commits/master').open.string)['sha']
    end
  end
end