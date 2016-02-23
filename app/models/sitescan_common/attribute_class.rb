module SitescanCommon
  # Attribute class model.
  #
  # name      - Attribute name.
  # type_id   - Attribute type (value: 1, range: 2, options: 3).
  # widget_id - Widget to display attribute (no widget: 0, memory size: 1, color: 2).
  # depend    - True if product's link depend on the attribute class.
  # attribute_class_group - The attribute class group.
  # weight    - The weight value of the attribute class inside the attribute group.
  class AttributeClass < ActiveRecord::Base
    self.table_name = :attribute_classes
    has_many :attribute_class_options, dependent: :delete_all
    has_and_belongs_to_many :categories
    belongs_to :attribute_class_group
    has_many :product_attributes, dependent: :restrict_with_error

    validates :name, presence: true
    scope :grid, -> { includes(:categories, :attribute_class_options).reorder(:weight) }

    # Select attribute classes related to the category. Order the result by weight.
    #
    # category_id - The category's id.
    # link        - True if need select link related attributes.
    # image       - True if need select image related attributes.
    #
    # Return ActiveRecord::Relation.
    scope :attrs_to_set, ->(category_id, link, image) {
      joins(:categories, :attribute_class_group).includes(product_attributes: [:value])
          .where('categories.id = :category_id and (:image or depend_link = :link) and (:link or depend_image = :image)',
                 {category_id: category_id, link: link, image: image})
          .reorder('attribute_class_groups.weight, attribute_classes.weight')
    }

    @@types = {'1': 'Значение', '2': 'Диапазон значений', '3': 'Значение из списка'}
    @@widgets = {'0': 'Heт', '1': 'Цвет', '2': 'Бренд', '3': 'Булево'}

    def type
      @@types[self.type_id.to_s.to_sym]
    end

    def widget
      @@widgets[self.widget_id.to_s.to_sym]
    end

    # Move the attribute class between groups and set order place.
    #
    # new_weight - The new weight.
    # new_group  - The new group.
    #
    # Returns nothing.
    def move(new_weight, new_group)
      if attribute_class_group_id != new_group

        # Reorder previous group.
        reorder_weights
        update attribute_class_group_id: new_group
      end
      reorder_weights new_weight
    end

    # Return attribute hash for attributes grid.
    #
    # cat_id - The ID of the product category.
    #
    # Returns hash:
    #  :id        - The ID of the attribute class.
    #  :_checked  - True if the attribute class related to the product category.
    #  :name      - The name of the attribute class.
    #  :unit      - The unit of the attribute class.
    #  :type_id   - The ID of the attribute class type.
    #  :type      - The string name of the attribute class type.
    #  :widget_id - ID of widget.
    #  :widget    - The string name of the widget.
    #  :depend    - String 'true' or 'false'
    #  :options   - The array of the attribute's options.
    def attribute_hash(cat_prod_id)
      checked = false
      if cat_prod_id
        category = Category.get_by_cat_prod_id cat_prod_id
        checked = categories.exists? category.id
      end
      {
          id: id,
          _checked: checked,
          name: name,
          unit: unit,
          type_id: type_id.to_s,
          type: type,
          group: false,
          widget_id: widget_id.to_s,
          widget: widget,
          depend_link: depend_link.to_s,
          depend_image: depend_image.to_s,
          weight: weight,
          options: attribute_class_options.select(:id, :value),
      }
    end

    def hash_attributable(attributable_id, attributable_type)
      attr = {id: id, name: name, type: type_id, unit: unit, group: attribute_class_group.name}
      attr[:_value] = hash_value attributable_id, attributable_type
      if type_id == 3
        options = attribute_class_options.select('id, value')
        attr[:options] = options
      end
      attr
    end

    def hash_link_attrs(attributable_id, attributable_type)
      attr = {id: id}
      attr[:_value] = hash_value attributable_id, attributable_type
      attr
    end

    def hash_value(attributable_id, attributable_type)
      pa = product_attributes.where(attributable_id: attributable_id, attributable_type: attributable_type).first
      case type_id
        when 1
          if pa then
            pa.value.value
          else
            nil
          end
        when 2
          if pa
            {from: pa.value.from, to: pa.value.to}
          else
            {from: nil, to: nil}
          end
        when 3
          if pa then
            pa.value.attribute_class_option_id
          else
            nil
          end
      end
    end

    def update(attributes, options = [])
      # if attributes[:type_id]
      AttributeClass.transaction do
        old_type_id = type_id
        result = super(attributes)
        # new_type_id = attributes[:type_id].to_i
        change_type(old_type_id, options)
        result
      end
    end

    class << self
      def types
        @@types
      end

      def wigets
        @@widgets
      end
    end

    private

    # Change attribute's type. All product's attributes will convert to new type.
    #
    # new_type_id - The new type's id.
    # options - Array of options.
    def change_type(old_type_id, options)
      option_ids = []
      case old_type_id
        when 1
          case type_id
            when 2
              change_product_attribute_types do |product_attribute|
                values = product_attribute.value.value.split ' - '
                AttributeRange.create from: values[0], to: values[1]
              end
            when 3
              change_product_attribute_types do |product_attribute|
                option = AttributeClassOption.find_or_create_by attribute_class_id: id,
                                                                value: product_attribute.value.value
                option_ids << option.id
                AttributeOption.create attribute_class_option_id: option.id
              end
          end
        when 2
          case type_id
            when 1
              change_product_attribute_types do |product_attribute|
                AttributeValue.create value: product_attribute.value.value
              end
            when 3
              change_product_attribute_types do |product_attribute|
                option = AttributeClassOption.find_or_create_by attribute_class_id: id,
                                                                value: product_attribute.value.value
                option_ids << option.id
                AttributeOption.create attribute_class_option_id: option.id
              end
          end
        when 3
          case type_id
            when 1
              change_product_attribute_types do |product_attribute|
                AttributeValue.create value: product_attribute.value.attribute_class_option.value
              end
            when 2
              change_product_attribute_types do |product_attribute|
                values = product_attribute.value.attribute_class_option.value.split ' - '
                AttributeRange.create from: values[0], to: values[1]
              end
          end
          AttributeClassOption.destroy_all attribute_class_id: id unless old_type_id == type_id
      end

      # If the attribute has options
      if type_id == 3

        # Update option if it exist or create new in other case.
        options.each do |option|
          opt = AttributeClassOption.find_or_create_by id: option[:id], attribute_class_id: id
          opt.update value: option[:value]
          option_ids << opt.id
        end
        self.attribute_class_option_ids = option_ids
      end
    end

    # Cycle through product's attributes to change type of values.
    def change_product_attribute_types
      product_attributes.each do |product_attribute|
        value = yield product_attribute
        product_attribute.value.delete
        value.product_attribute = product_attribute
      end
    end

    # Recalculate weights in current group. If new weight not set, then current attribute wont not include.
    #
    # new_weight  - The new weight value for current attribute (default: nil).
    #
    # Examples
    #
    #  reorder_weights(3)
    #
    #  reorder_weights
    #
    # Returns nothing.
    def reorder_weights(new_weight = nil)
      update weight: new_weight
      w = 1
      self.class.where(attribute_class_group_id: attribute_class_group_id).where.not(id: id).reorder(:weight).each do |attr|
        w = w + 1 if w == new_weight
        attr.update weight: w
        w = w + 1
      end
    end
  end
end