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

  def initialize(hosts_path = nil)
    @conf_path = hosts_path || default_hosts_file_path
    @content   = read_file(@conf_path)
    @params    = parse_conf(@content)
  end

  filter = FilterTable.create
  filter.add_accessor(:where)
        .add_accessor(:entries)
        .add(:ip_address,     field: 'ip_address')
        .add(:primary_name,   field: 'primary_name')
        .add(:all_host_names, field: 'all_host_names')
  filter.connect(self, :params)

  private

  def default_hosts_file_path
    inspec.os.windows? ? 'C:\windows\system32\drivers\etc\hosts' : '/etc/hosts'
  end

  def parse_conf(content)
    content.map do |line|
      data, _ = parse_comment_line(line, comment_char: '#', standalone_comments: false)
      parse_line(data) unless data == ''
    end.compact
  end

  def parse_line(line)
    line_parts = line.split
    return nil unless line_parts.length >= 2
    {
      'ip_address'     => line_parts[0],
      'primary_name'   => line_parts[1],
      'all_host_names' => line_parts[1..-1],
    }
  end

  def read_file(conf_path = @conf_path)
    file = inspec.file(conf_path)

    unless file.file?
      raise Inspec::Exceptions::ResourceSkipped,
            "Can't find file. \"#{conf_path}\""
    end

    if file.content.lines.count <= 0
      raise Inspec::Exceptions::ResourceSkipped,
            "File has no content. \"#{conf_path}\""
    end

    file.content.lines
  end
end
