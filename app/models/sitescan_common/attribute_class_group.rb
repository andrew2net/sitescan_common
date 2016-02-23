module SitescanCommon
  # Public: Attribute class group model.
  #
  # name   - Group name.
  # weight - Weight of group.
  class AttributeClassGroup < ActiveRecord::Base
    self.table_name = :attribute_class_groups
    has_many :attribute_classes, dependent: :destroy
    validates :name, presence: true

    # Public: Set new weight to the attribute class group and recalculate the weights.
    #
    # new_weight - New weight of the group.
    #
    # Returns nothing.
    def move(new_weight)
      update weight: new_weight
      w = 1
      self.class.where.not(id: id).reorder(:weight).each do |g|
        w = w + 1 if w == new_weight
        g.update weight: w
        w = w + 1
      end
    end

    def attribute_hash
      {id: id, name: name, group: true, weight: weight}
    end
  end
end
