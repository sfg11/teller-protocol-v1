pragma solidity 0.5.17;


/*****************************************************************************************************/
/**                                             WARNING                                             **/
/**                                  THIS CONTRACT IS UPGRADEABLE!                                  **/
/**  ---------------------------------------------------------------------------------------------  **/
/**  Do NOT change the order of or PREPEND any storage variables to this or new versions of this    **/
/**  contract as this will cause the the storage slots to be overwritten on the proxy contract!!    **/
/**                                                                                                 **/
/**  Visit https://docs.openzeppelin.com/upgrades/2.6/proxies#upgrading-via-the-proxy-pattern for   **/
/**  more information.                                                                              **/
/*****************************************************************************************************/
/**
    @notice This interface defines the functions to create the ATM instances.
    @author develop@teller.finance
 */
interface IATMFactory {
    /** Events */

    /**
        @notice This event is emitted when a new ATM instance is created.
        @param creator creator address.
        @param atmGovernanceAddress new ATM Governance instance address.
        @param atmTokenAddress new ATM Token instance address.
     */
    event ATMCreated(
        address indexed creator,
        address indexed atmGovernanceAddress,
        address indexed atmTokenAddress
    );

    /**
        @notice This event is emitted when the setting is updated.
        @param sender address that sent the transaction.
        @param oldSettings the old settings address.
        @param newSettings the new settings address.
     */
    event SettingsUpdated(
        address indexed sender,
        address oldSettings,
        address newSettings
    );

    /**
        @notice This event is emitted when the ATM setting is updated.
        @param sender address that sent the transaction.
        @param oldATMSettings the old ATM settings address.
        @param newATMSettings the new ATM settings address.
     */
    event ATMSettingsUpdated(
        address indexed sender,
        address oldATMSettings,
        address newATMSettings
    );

    /* State Variables */

    /** Modifiers */

    /* Constructor */

    /** External Functions */

    /**
        @notice It creates a new ATM instance.
        @param name ATM token name.
        @param symbol ATM token symbol
        @param decimals ATM token decimals 
        @param cap ATM token max cap.
        @param maxVestingsPerWallet max vestings per wallet for the ATM token.
        @param atmGovernanceLogic the atm governance instance address.
        @param atmTokenLogic the atm token instance address.
        @return the new ATM governance instance address.
     */
    function createATM(
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        uint256 cap,
        uint256 maxVestingsPerWallet,
        address atmGovernanceLogic,
        address atmTokenLogic
    ) external returns (address);

    /**
        @notice It updates the current settings.
        @param newSettingsAddress the new setting address.
     */
    function setSettings(address newSettingsAddress) external;

    /**
        @notice It updates the current atm settings.
        @param newATMSettingsAddress The new settings address.
     */
    function setATMSettings(address newATMSettingsAddress) external;

    /**
        @notice Tests whether an address is an ATM instance or not.
        @param atmAddress address to test.
        @return true if the given address is an ATM. Otherwise it returns false.
     */
    function isATM(address atmAddress) external view returns (bool);

    /**
        @notice Gets the ATMs list.
        @return the list of ATMs.
     */
    function getATMs() external view returns (address[] memory);

    /**
        @notice Returns the address of the ATM Settings contract.
        @return Address of the ATM settings contract
     */
    function getATMSettings() external view returns (address);

    /**
        @notice Returns the address of the Settings contract
        @return Address of the settings contract
     */
    function getSettings() external view returns (address);

    /**
        @notice Returns the atm token address of a given associated atm address.
        @param atmAddress ATM address to test
        @return Address of the associated ATM Token
     */
    function getATMToken(address atmAddress) external view returns (address);
}
