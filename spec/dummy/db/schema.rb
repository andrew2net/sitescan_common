# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160315172842) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "admins", force: :cascade do |t|
    t.string   "first_name"
    t.string   "last_name"
    t.string   "email",                           null: false
    t.string   "crypted_password",                null: false
    t.string   "password_salt",                   null: false
    t.string   "persistence_token",               null: false
    t.string   "single_access_token",             null: false
    t.string   "perishable_token",                null: false
    t.integer  "login_count",         default: 0, null: false
    t.integer  "failed_login_count",  default: 0, null: false
    t.datetime "last_request_at"
    t.datetime "current_login_at"
    t.datetime "last_login_at"
    t.string   "current_login_ip"
    t.string   "last_login_ip"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
  end

  create_table "admins_roles", force: :cascade do |t|
    t.integer "admin_id"
    t.integer "role_id"
  end

  add_index "admins_roles", ["admin_id"], name: "index_admins_roles_on_admin_id", using: :btree
  add_index "admins_roles", ["role_id"], name: "index_admins_roles_on_role_id", using: :btree

  create_table "attribute_booleans", force: :cascade do |t|
    t.boolean  "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "attribute_class_groups", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer  "weight"
  end

  create_table "attribute_class_options", force: :cascade do |t|
    t.integer  "attribute_class_id"
    t.string   "value",              null: false
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
  end

  add_index "attribute_class_options", ["attribute_class_id"], name: "index_attribute_class_options_on_attribute_class_id", using: :btree

  create_table "attribute_class_options_attribute_lists", id: false, force: :cascade do |t|
    t.integer "attribute_class_option_id"
    t.integer "attribute_list_id"
  end

  add_index "attribute_class_options_attribute_lists", ["attribute_class_option_id"], name: "index_acoao_on_attribute_class_option_id", using: :btree
  add_index "attribute_class_options_attribute_lists", ["attribute_list_id"], name: "index_acoao_on_attribute_list_id", using: :btree

  create_table "attribute_classes", force: :cascade do |t|
    t.string   "name",                                                null: false
    t.string   "unit",                     limit: 10
    t.boolean  "depend_link",                         default: false
    t.integer  "type_id",                             default: 0
    t.integer  "widget_id",                           default: 0
    t.datetime "created_at",                                          null: false
    t.datetime "updated_at",                                          null: false
    t.integer  "attribute_class_group_id",                            null: false
    t.integer  "weight"
    t.boolean  "depend_image",                        default: false
    t.boolean  "show_in_catalog"
    t.boolean  "searchable"
  end

  add_index "attribute_classes", ["attribute_class_group_id"], name: "index_attribute_classes_on_attribute_class_group_id", using: :btree

  create_table "attribute_classes_categories", id: false, force: :cascade do |t|
    t.integer "attribute_class_id"
    t.integer "category_id"
  end

  add_index "attribute_classes_categories", ["attribute_class_id"], name: "index_attribute_classes_categories_on_attribute_class_id", using: :btree
  add_index "attribute_classes_categories", ["category_id"], name: "index_attribute_classes_categories_on_category_id", using: :btree

  create_table "attribute_lists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "attribute_options", force: :cascade do |t|
    t.integer  "attribute_class_option_id"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "attribute_options", ["attribute_class_option_id"], name: "index_attribute_options_on_attribute_class_option_id", using: :btree

  create_table "attribute_ranges", force: :cascade do |t|
    t.integer  "from"
    t.integer  "to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "attribute_strings", force: :cascade do |t|
    t.string   "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "attrubute_numbers", force: :cascade do |t|
    t.decimal  "value",      precision: 10, scale: 2
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  create_table "categories", force: :cascade do |t|
    t.string   "name"
    t.integer  "parent_id"
    t.integer  "lft",                            null: false
    t.integer  "rgt",                            null: false
    t.integer  "depth",              default: 0, null: false
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.string   "image_file_name"
    t.string   "image_content_type"
    t.integer  "image_file_size"
    t.datetime "image_updated_at"
    t.boolean  "show_on_main"
    t.string   "path"
  end

  add_index "categories", ["lft"], name: "index_categories_on_lft", using: :btree
  add_index "categories", ["parent_id"], name: "index_categories_on_parent_id", using: :btree
  add_index "categories", ["path"], name: "index_categories_on_path", unique: true, using: :btree
  add_index "categories", ["rgt"], name: "index_categories_on_rgt", using: :btree

  create_table "categories_products", id: false, force: :cascade do |t|
    t.integer "category_id"
    t.integer "product_id"
  end

  add_index "categories_products", ["category_id"], name: "index_categories_products_on_category_id", using: :btree
  add_index "categories_products", ["product_id"], name: "index_categories_products_on_product_id", using: :btree

  create_table "disabled_products", force: :cascade do |t|
    t.integer  "product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "fetch_ext_resources", force: :cascade do |t|
    t.integer  "search_result_domain_id"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  add_index "fetch_ext_resources", ["search_result_domain_id"], name: "index_fetch_ext_resources_on_search_result_domain_id", using: :btree

  create_table "key_words", force: :cascade do |t|
    t.integer  "category_id",             null: false
    t.string   "text"
    t.integer  "counter",     default: 0
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  add_index "key_words", ["category_id"], name: "index_key_words_on_category_id", using: :btree

  create_table "key_words_search_results", id: false, force: :cascade do |t|
    t.integer "key_word_id"
    t.integer "search_result_id"
  end

  add_index "key_words_search_results", ["key_word_id"], name: "index_key_words_search_results_on_key_word_id", using: :btree
  add_index "key_words_search_results", ["search_result_id"], name: "index_key_words_search_results_on_search_result_id", using: :btree

  create_table "menu_item_translations", force: :cascade do |t|
    t.integer  "menu_item_id", null: false
    t.string   "locale",       null: false
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.string   "title",        null: false
  end

  add_index "menu_item_translations", ["locale"], name: "index_menu_item_translations_on_locale", using: :btree
  add_index "menu_item_translations", ["menu_item_id"], name: "index_menu_item_translations_on_menu_item_id", using: :btree

  create_table "menu_items", force: :cascade do |t|
    t.integer  "type_id",    null: false
    t.integer  "page_id"
    t.integer  "weight"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "page_translations", force: :cascade do |t|
    t.integer  "page_id",     null: false
    t.string   "locale",      null: false
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.string   "title"
    t.text     "text"
    t.string   "keywords"
    t.string   "description"
  end

  add_index "page_translations", ["locale"], name: "index_page_translations_on_locale", using: :btree
  add_index "page_translations", ["page_id"], name: "index_page_translations_on_page_id", using: :btree

  create_table "pages", force: :cascade do |t|
    t.string   "url"
    t.integer  "type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "product_attributes", force: :cascade do |t|
    t.integer  "attributable_id"
    t.integer  "attribute_class_id"
    t.integer  "value_id"
    t.string   "value_type"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.string   "attributable_type"
  end

  add_index "product_attributes", ["attributable_type", "attributable_id"], name: "index_product_attributes_attributable", using: :btree
  add_index "product_attributes", ["attribute_class_id"], name: "index_product_attributes_on_attribute_class_id", using: :btree
  add_index "product_attributes", ["value_type", "value_id"], name: "index_product_attributes_on_value_type_and_value_id", using: :btree

  create_table "product_images", force: :cascade do |t|
    t.integer  "position"
    t.integer  "product_id"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.string   "attachment_file_name"
    t.string   "attachment_content_type"
    t.integer  "attachment_file_size"
    t.datetime "attachment_updated_at"
  end

  add_index "product_images", ["product_id"], name: "index_product_images_on_product_id", using: :btree

  create_table "product_search_products", force: :cascade do |t|
    t.integer "product_id"
    t.integer "search_product_id"
  end

  add_index "product_search_products", ["product_id", "search_product_id"], name: "product_seatch_product_unique", unique: true, using: :btree
  add_index "product_search_products", ["search_product_id"], name: "index_product_search_products_on_search_product_id", using: :btree

  create_table "products", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "roles", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "search_attribute_paths", force: :cascade do |t|
    t.integer  "type_id"
    t.string   "value"
    t.integer  "search_result_domain_id"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.integer  "weight"
  end

  add_index "search_attribute_paths", ["search_result_domain_id", "type_id", "weight"], name: "domain_type_weight", unique: true, using: :btree
  add_index "search_attribute_paths", ["search_result_domain_id"], name: "index_search_attribute_paths_on_search_result_domain_id", using: :btree

  create_table "search_product_errors", force: :cascade do |t|
    t.integer  "type_id"
    t.integer  "search_result_id"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  add_index "search_product_errors", ["search_result_id", "type_id"], name: "index_search_product_errors_on_search_result_id_and_type_id", unique: true, using: :btree
  add_index "search_product_errors", ["search_result_id"], name: "index_search_product_errors_on_search_result_id", using: :btree

  create_table "search_products", force: :cascade do |t|
    t.string   "name"
    t.decimal  "price",            precision: 12, scale: 2
    t.integer  "search_result_id"
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
  end

  add_index "search_products", ["search_result_id"], name: "index_search_products_on_search_result_id", using: :btree

  create_table "search_result_domains", force: :cascade do |t|
    t.string   "domain"
    t.binary   "cookie"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.integer  "status_id",  default: 1
  end

  create_table "search_results", force: :cascade do |t|
    t.string   "title"
    t.string   "link"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.integer  "counter",                 default: 0
    t.integer  "search_result_domain_id"
  end

  add_index "search_results", ["link"], name: "index_search_results_on_link", unique: true, using: :btree
  add_index "search_results", ["search_result_domain_id"], name: "index_search_results_on_search_result_domain_id", using: :btree

  create_table "settings", force: :cascade do |t|
    t.string   "name"
    t.string   "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "attribute_class_options", "attribute_classes"
  add_foreign_key "fetch_ext_resources", "search_result_domains"
  add_foreign_key "key_words", "categories"
  add_foreign_key "product_images", "products"
  add_foreign_key "product_search_products", "products"
  add_foreign_key "product_search_products", "search_products"
  add_foreign_key "search_attribute_paths", "search_result_domains"
  add_foreign_key "search_product_errors", "search_results"
  add_foreign_key "search_products", "search_results"
  add_foreign_key "search_results", "search_result_domains"
end
