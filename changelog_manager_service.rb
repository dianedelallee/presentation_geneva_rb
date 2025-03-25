require 'active_support'
require 'active_support/core_ext'

class ChangelogManagerService
  EXCLUDE_VARS = %w[. ..].freeze

  def initialize
    @changelog_to_add = ''
    @wagon_file = find_wagon_name_file

    if @wagon_file.present? && File.exist?(@wagon_file)
      @wagon_name = File.read(@wagon_file)
    else
      now = Time.now.strftime("%Y.%m.%d-%H:%M")
      @wagon_name = "## [stowaway-changes.#{now}]\n"
    end
  end

  def find_wagon_name_file
    files = Dir.glob("./changelog/*.md").select { |e| File.file? e }
    files[0]
  end

  def create_new_content
    puts "creating the new content ..."
    create_unreleased_changelog
    add_changelog_subtitle
    file = File.read('./CHANGELOG.md')
    "#{@changelog_to_add}#{file}"
  end

  def write_new_changelog
    new_content = create_new_content
    File.open('./CHANGELOG.md', 'w') { |line| line.puts new_content }
    clear_unreleased_files

    puts "write changelog changelog_to_add"
    puts @changelog_to_add
    return if @changelog_to_add.empty?
  end

  private

  def add_changelog_subtitle
    return if @changelog_to_add.empty?

    puts "adding the wagon name to the changelog ..."
    @changelog_to_add = "#{@wagon_name}#{@changelog_to_add}\n"
  end

  def clear_unreleased_files
    puts "deleting the readmes for features / fixes ..."
    folders = Dir.entries('./changelog/').reject { |entry| (EXCLUDE_VARS.include? entry) }
    folders.each do |folder|
      delete_files(path: "./changelog/#{folder}")
    end
    puts "deleting the new readme for the daily wagon"
    FileUtils.rm_f(@wagon_file) if @wagon_file.present?
  end

  def concatenate_files(list_of_files:)
    list_of_files.each do |file|
      first_line = File.open(file, &:readline)
      starts_with_dash = first_line.start_with? '- '
      @changelog_to_add << "\n" if @changelog_to_add.end_with? "```\n"
      File.readlines(file).each_with_index do |line, index|
        @changelog_to_add << (index.zero? ? '- ' : '  ') if line.present? && !starts_with_dash
        @changelog_to_add << line.to_s
      end
      @changelog_to_add << "\n" unless File.read(file)[/\n$/]
    end
  end

  def subpart_unreleased_changelog(path:, title:)
    files = Dir.glob("#{path}/**/*").select { |e| File.file? e }.reject { |i| i == "#{path}/README.md" }
    if files.length.positive?
      @changelog_to_add << "\n#{title}\n\n"
      concatenate_files(list_of_files: files)
    end
  end

  def create_unreleased_changelog
    folders = Dir.entries('./changelog/').reject { |entry| (EXCLUDE_VARS.include? entry) }
    folders.each do |folder|
      puts "construction of changelog for folder: #{folder}"
      subpart_unreleased_changelog(path: "./changelog/#{folder}", title: "### #{folder.capitalize}")
    end
  end

  def delete_files(path:)
    files = Dir.glob("#{path}/**/*").select { |e| File.file? e }.reject { |i| i == "#{path}/README.md" }
    files.each do |file|
      File.delete(file)
    end
  end
end

ChangelogManagerService.new.write_new_changelog