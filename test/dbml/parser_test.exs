defmodule DBML.ParserTest do
  use ExUnit.Case, async: true

  describe "parse/1" do
    test "parses project" do
      assert {:ok, tokens} = parse("""
      project CMS {
        database_type: "PostgreSQL"
        note: 'CMS database'
      }

      //// -- LEVEL 1
      //// -- tables and references

      // Creating tables
      table users as U {
        id int [pk, increment]
        full_name varchar
        created_at timestamp
        country_code int
      }

      table countries {
        code int [pk]
        name varchar
        continent_name varchar
       }

      // Creating references
      // You can also define relaionship separately
      // > many-to-one; < one-to-many; - one-to-one
      ref: U.country_code > countries.code
      ref: merchants.country_code > countries.code

      //----------------------------------------------//

      //// -- LEVEL 2
      //// -- Adding column settings

      table order_items {
        order_id int [ref: > orders.id] // inline relationship (many-to-one)
        product_id int
        quantity int [default: 1] // default value
      }

      ref: order_items.product_id > products.id

      table orders {
        id int [pk] // primary key
        user_id int [not null, unique]
        status varchar
        created_at varchar [note: 'When order created'] // add column note
      }

      //----------------------------------------------//

      //// -- Level 3 
      //// -- Enum, indexes

      // Enum for 'products' table below
      enum products_status {
        out_of_stock
        in_stock
        running_low [note: 'less than 20'] // add column note
      }

      // indexes: You can define a single or multi-column index 
      table products {
        id int [pk]
        name varchar
        merchant_id int [not null]
        price int
        status products_status
        created_at datetime [default: `now()`]
        
        indexes {
          (merchant_id, status) [name: "product_status"]
          id [unique]
        }

        note {
          'asdfasd'
        }
      }

      table merchants {
        id int
        country_code int
        merchant_name varchar
        
        "created at" varchar
        admin_id int [ref: > U.id]
        indexes {
          (id, country_code) [pk]
        }
      }

      table merchant_periods {
        id int [pk]
        merchant_id int
        country_code int
        start_date datetime
        end_date datetime
      }

      ref: products.merchant_id > merchants.id // many-to-one
      """)

      assert tokens == []
    end
  end

  defp parse(doc) do
    DBML.parse(doc)
  end
end
