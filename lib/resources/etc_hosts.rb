# encoding: utf-8

require 'utils/parser'

class EtcHosts < Inspec.resource(1)
  name 'etc_hosts'
  supports platform: 'linux'
  supports platform: 'bsd'
  supports platform: 'windows'
  desc 'Use the etc_hosts InSpec audit resource to find an
    ip_address and its associated hosts'
  example "
    describe etc_hosts.where { ip_address == '127.0.0.1' } do
      its('ip_address') { should cmp '127.0.0.1' }
      its('primary_name') { should cmp 'localhost' }
      its('all_host_names') { should eq [['localhost', 'localhost.localdomain', 'localhost4', 'localhost4.localdomain4']] }
    end
  "

  attr_reader :params

  include CommentParser

  DEFAULT_UNIX_PATH    = '/etc/hosts'.freeze
  DEFAULT_WINDOWS_PATH = 'C:\windows\system32\drivers\etc\hosts'.freeze

  def initialize(hosts_path = nil)
    @conf_path = hosts_path || default_hosts_file_path
    @content   = read_file(@conf_path)
    @params    = parse_conf(@content.lines)
  end

  FilterTable.create
             .add_accessor(:where)
             .add_accessor(:entries)
             .add(:ip_address,     field: 'ip_address')
             .add(:primary_name,   field: 'primary_name')
             .add(:all_host_names, field: 'all_host_names')
             .connect(self, :params)

  private

  def default_hosts_file_path
    inspec.os.windows? ? DEFAULT_WINDOWS_PATH : DEFAULT_UNIX_PATH
  end

  def read_file(conf_path = @conf_path)
    file = inspec.file(conf_path)

    skip("Can't find file. \"#{conf_path}\"") unless file.file?

    skip("File has no content. \"#{conf_path}\"") if file.content.lines.empty?

    file.content
  end

  def skip(message)
    raise Inspec::Exceptions::ResourceSkipped, message
  end

  def parse_conf(lines)
    lines.reject(&:empty?).reject(&comment?).map(&parse_data).map(&format_data)
  end

  def comment?
    parse_options = { comment_char: '#', standalone_comments: false }

    ->(data) { parse_comment_line(data, parse_options).first.empty? }
  end

  def parse_data
    ->(data) { [data.split[0], data.split[1], data.split[1..-1]] }
  end

  def format_data
    ->(data) { %w{ip_address primary_name all_host_names}.zip(data).to_h }
  end
end
