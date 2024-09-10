// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/structs/EnumerableMap.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

/**
 * @dev Library for managing an enumerable variant of Solidity's
 * https://solidity.readthedocs.io/en/latest/types.html#mapping-types[`mapping`]
 * type.
 *
 * Maps have the following properties:
 *
 * - Entries are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Entries are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableMap for EnumerableMap.UintToAddressMap;
 *
 *     // Declare a set state variable
 *     EnumerableMap.UintToAddressMap private myMap;
 * }
 * ```
 *
 * As of v3.0.0, only maps of type `uint256 -> address` (`UintToAddressMap`) are
 * supported.
 */
library ModifiedEnumerableMapUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Map type with
    // bytes32 keys and values.
    // The Map implementation uses private functions, and user-facing
    // implementations (such as Uint256ToAddressMap) are just wrappers around
    // the underlying Map.
    // This means that we can only create new EnumerableMaps for types that fit
    // in bytes32.

    struct Map {
        // Storage of keys
        EnumerableSetUpgradeable.Bytes32Set _keys;
        mapping(bytes32 => string) _values;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function _set(
        Map storage map,
        bytes32 key,
        string memory value
    ) private returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @dev Removes a key-value pair from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function _remove(Map storage map, bytes32 key) private returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function _contains(Map storage map, bytes32 key) private view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @dev Returns the number of key-value pairs in the map. O(1).
     */
    function _length(Map storage map) private view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @dev Returns the key-value pair stored at position `index` in the map. O(1).
     *
     * Note that there are no guarantees on the ordering of entries inside the
     * array, and it may change when more entries are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Map storage map, uint256 index) private view returns (bytes32, string memory) {
        bytes32 key = map._keys.at(index);
        return (key, map._values[key]);
    }

    /**
     * @dev Tries to returns the value associated with `key`.  O(1).
     * Does not revert if `key` is not in the map.
     */
    function _tryGet(Map storage map, bytes32 key) private view returns (bool, string memory) {
        string memory value = map._values[key];
        return (_contains(map, key), value);
    }

    /**
     * @dev Returns the value associated with `key`.  O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function _get(Map storage map, bytes32 key) private view returns (string memory) {
        string memory value = map._values[key];
        require(_contains(map, key), "EnumerableMap: nonexistent key");
        return value;
    }

    /**
     * @dev Same as {_get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {_tryGet}.
     */
    function _get(
        Map storage map,
        bytes32 key,
        string memory errorMessage
    ) private view returns (string memory) {
        string memory value = map._values[key];
        require(_contains(map, key), errorMessage);
        return value;
    }

    // StringToBytesMap

    struct StringToBytesMap {
        Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(
        StringToBytesMap storage map,
        string memory key,
        string memory value
    ) internal returns (bool) {
        return _set(map._inner, bytes32(abi.encodePacked(key)), value);
    }

    // /**
    //  * @dev Removes a value from a set. O(1).
    //  *
    //  * Returns true if the key was removed from the map, that is if it was present.
    //  */
    function remove(StringToBytesMap storage map, string memory key) internal returns (bool) {
        return _remove(map._inner, bytes32(abi.encodePacked(key)));
    }

    // /**
    //  * @dev Returns true if the key is in the map. O(1).
    //  */
    function contains(StringToBytesMap storage map, string memory key) internal view returns (bool) {
        return _contains(map._inner, bytes32(abi.encodePacked(key)));
    }

    // /**
    //  * @dev Returns the number of elements in the map. O(1).
    //  */
    function length(StringToBytesMap storage map) internal view returns (uint256) {
        return _length(map._inner);
    }

    // /**
    //  * @dev Returns the element stored at position `index` in the set. O(1).
    //  * Note that there are no guarantees on the ordering of values inside the
    //  * array, and it may change when more values are added or removed.
    //  *
    //  * Requirements:
    //  *
    //  * - `index` must be strictly less than {length}.
    //  */
    function at(StringToBytesMap storage map, uint256 index) internal view returns (string memory, string memory) {
        (bytes32 key, string memory value) = _at(map._inner, index);
        return (string(abi.encodePacked(key)), value);
    }

    /**
     * @dev Tries to returns the value associated with `key`.  O(1).
     * Does not revert if `key` is not in the map.
     *
     * _Available since v3.4._
     */
    function tryGet(StringToBytesMap storage map, string memory key) internal view returns (bool, string memory) {
        (bool success, string memory value) = _tryGet(map._inner, bytes32(abi.encodePacked(key)));
        return (success, value);
    }

    /**
     * @dev Returns the value associated with `key`.  O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(StringToBytesMap storage map, string memory key) internal view returns (string memory) {
        return _get(map._inner, bytes32(abi.encodePacked(key)));
    }

}
