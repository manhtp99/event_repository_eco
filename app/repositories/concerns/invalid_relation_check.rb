# frozen_string_literal: true

module InvalidRelationCheck
    extend ActiveSupport::Concern
  
    included do
      def exclude_id?(attributes, relation_ids)
        attribute_ids = attributes.pluck(:id).compact
        attribute_ids.any? { |id| relation_ids.exclude?(id.to_i) }
      end
  
      def invalid_relation(attributes, relation_name)
        return unless attributes
  
        relation_ids = record.send(relation_name).pluck(:id)
        exclude_id?(attributes, relation_ids)
      end
  
      def raise_invalid_relation(attributes, relations_name)
        relations_name.each do |relation_name|
          if invalid_relation(attributes["#{relation_name}_attributes".to_sym], relation_name)
            raise GraphQL::ExecutionError, I18n.t("errors_message.model.invalid_relation.#{relation_name}")
          end
        end
      end
    end
  end
  