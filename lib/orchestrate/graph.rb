module Orchestrate

  # Manages graph relationships for a KeyValue item.
  class Graph

    # Instantiates a new Graph manager.
    # @param kv_item [Orchestrate::KeyValue] The KeyValue item on the starting end of the graph.
    def initialize(kv_item)
      @kv_item = kv_item
      @types = {}
    end

    # Accessor for graph relation types.
    # @return [RelationStem]
    def [](relation_type)
      @types[relation_type.to_s] || RelationStem.new(@kv_item, relation_type.to_s)
    end

    # A directed relationship against a single KeyValue object.
    class RelationStem

      # the KeyValue object this RelationStem acts on behalf of.
      # @return [Orchestrate::KeyValue]
      attr_accessor :kv_item

      # the type of relation this RelationStem interacts with.
      # @return [String]
      attr_accessor :type

      # Instantiates a new RelationStem
      # @param kv_item [Orchestrate::KeyValue] the KeyValue object this RelationStem acts on behalf of.
      # @param type_name [#to_s] the type of relation this RelationStem interacts with.
      def initialize(kv_item, type_name)
        @kv_item = kv_item
        @client = kv_item.collection.app.client
        @type = type_name.to_s
      end

      # [Creates a relationship between two objects](http://orchestrate.io/docs/api/#graph/put).
      # Relations can span collections.
      # @overload <<(key_value_item)
      #   @param key_value_item [Orchestrate::KeyValue] The KeyValue item to create the relationship with.
      # @overload <<(collection_name, key_name)
      #   @param collection_name [#to_s] The collection which the other item belongs to.
      #   @param key_name [#to_s] The key of the other item.
      # @return [Orchestrate::API::Response]
      def <<(other_item_or_collection_name, other_key=nil)
        coll, key = get_collection_and_key(kv_item, nil)
        other_collection, other_key = get_collection_and_key(other_item_or_collection_name, other_key)
        @client.put_relation(coll, key, type, other_collection, other_key)
      end
      alias :push :<<

      # [Deletes a relationship between two objects](http://orchestrate.io/docs/api/#graph/delete29).
      # @overload delete(key_value_item)
      #   @param key_value_item [Orchestrate::KeyValue] The KeyValue item to create the relationship with.
      # @overload delete(collection_name, key_name)
      #   @param collection_name [#to_s] The collection which the other item belongs to.
      #   @param key_name [#to_s] The key of the other item.
      # @return [Orchestrate::API::Response]
      def delete(other_item_or_collection_name, other_key=nil)
        coll, key = get_collection_and_key(kv_item, nil)
        other_collection, other_key = get_collection_and_key(other_item_or_collection_name, other_key)
        @client.delete_relation(coll, key, type, other_collection, other_key)
      end

      # Adds depth to the retrieval of related items.
      # @param type_n [#to_s] The kind of the relation for the second layer of depth to retreive results for.
      # @return [Traversal]
      def [](type_n)
        Traversal.new(kv_item, [type, type_n.to_s])
      end

      include Enumerable
      def each(&block)
        Traversal.new(kv_item, [type]).each(&block)
      end

      def lazy
        each.lazy
      end

      private
      def get_collection_and_key(item_or_collection, key)
        if item_or_collection.kind_of?(KeyValue)
          collection = item_or_collection.collection_name
          key = item_or_collection.key
        else
          collection = item_or_collection
        end
        [collection, key]
      end

      class Traversal
        attr_accessor :kv_item
        attr_accessor :edges

        def initialize(kv_item, edge_names)
          @kv_item = kv_item
          @edges = edge_names
          @client = kv_item.collection.app.client
        end

        def [](edge)
          self.class.new(kv_item, [edges, edge].flatten)
        end

        include Enumerable
        def each(&block)
          @response = @client.get_relations(kv_item.collection_name, kv_item.key, *edges)
          return enum_for(:each) unless block
          # raise ResultsNotReady if @client.http.parallel_manager
          @response.results.each do |listing|
            listing_collection = kv_item.collection.app[listing['path']['collection']]
            yield KeyValue.from_listing(listing_collection, listing, @response)
          end
        end

      end
    end

  end
end

