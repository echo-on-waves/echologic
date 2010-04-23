class Profile < ActiveRecord::Base

  # Every profile has to belong to a user.
  belongs_to :user,       :dependent => :destroy
  has_many :web_addresses, :through => :user
  has_many :memberships,  :through => :user
  has_many :concernments, :through => :user
  has_many :spoken_languages, :through => :user

  validates_presence_of :user_id
  validates_length_of :about_me, :maximum => 1024, :allow_nil => true
  validates_length_of :motivation, :maximum => 1024, :allow_nil => true
  
 
  include ProfileExtension::Completeness


  # named scope, only returning profiles with 'show_profile' flag set to true
  # currently this flag is true for alle users before release 0.5 and everyone who ever had more then 50% of his profile filled
  # FIXME: this scope isn't used, because the current profile search implementation doesn't work with additional scopes
  named_scope :published, :conditions => { :show_profile => 1 }  
  
  named_scope :by_last_name_first_name_id, :include => :user, :order => 'CASE WHEN last_name IS NULL OR last_name="" THEN 1 ELSE 0 END, last_name, first_name, user.id asc'
 
  # callback for paperclip
 
  
  # There are two kind of people in the world..
  @@gender = {
    false => I18n.t('users.profile.gender.male'),
    true  => I18n.t('users.profile.gender.female')
  }

  # Access for the class variable
  def self.gender
    @@gender
  end

  # Returns the localized gender
  def localized_gender
    @@gender[female] || '' # I18n.t('application.general.undefined')
  end

  # Handle attached user picture through paperclip plugin
  has_attached_file :avatar, :styles => { :big => "128x>", :small => "x45>" },
                    :default_url => "/images/default_:style_avatar.png"
  validates_attachment_size :avatar, :less_than => 5.megabytes
  validates_attachment_content_type :avatar, :content_type => ['image/jpeg', 'image/png']
  # paperclip callback, used to recalculate completeness when uploading an avatar
  after_avatar_post_process :calculate_completeness

  # Return the full name of the user composed of first- and lastname
  def full_name
    [first_name, last_name].select { |s| s.try(:any?) }.join(' ')
  end

  # Return the formatted location of the user
  # TODO conditions in compact form?
  #  - something like this?: [city, country].select{|s|s.try(:any?)}.join(', ')
  def location
    [city, country].select { |s| s.try(:any?) }.join(', ')
  end

  # Return the first membership. If none is set return empty-string.
  def first_membership
    return "" if memberships.blank?
    "#{memberships.first.organisation} - #{memberships.first.position}"
  end

  def self.search_profiles(sort, value, opts={} )
    
    #sorting the or arguments
    sort_string = "c.sort = #{sort}" 
    or_attrs = opts[:attrs] || %w(p.first_name p.last_name p.city p.country p.about_me p.motivation u.email t.value m.position m.organisation)
    or_conditions = or_attrs.map{|attr|"#{attr} LIKE ?"}.join(" OR ")
    
    #sorting the and arguments
    and_conditions = opts[:conditions] || ["u.active = 1","p.show_profile = 1"]
    and_conditions.insert(0,sort_string) if !sort.blank?    
    
    #all getting along like really good friends
    and_conditions << "(#{or_conditions})"
    
    #Rambo 1
    query_part_1 = <<-END
      select distinct p.*, u.email
      from
        profiles p
        LEFT JOIN users u        ON u.id = p.user_id
        LEFT JOIN memberships m  ON u.id = m.user_id
        LEFT JOIN concernments c ON (u.id = c.user_id)
        LEFT JOIN tags t         ON (t.id = c.tag_id)
      where
    END
    #Rambo 2
    query_part_2 = and_conditions.join(" AND ")
    #Rambo 3
    query_part_3 = " order by CASE WHEN last_name IS NULL OR last_name='' THEN 1 ELSE 0 END, p.last_name, p.first_name, u.id asc;"
    
    #All Rambo's in one
    query = query_part_1+query_part_2+query_part_3
    value = "%#{value}%"
     
    conditions = [query, *([value] * or_attrs.size)]
    profiles = find_by_sql(conditions)
  end
end
