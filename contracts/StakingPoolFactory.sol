pragma solidity ^0.5.0;

import "./interfaces/IStakingPoolFactoryStorage.sol";
import "./interfaces/IStakingPoolFactory.sol";
import "./interfaces/IOwned.sol";

import "./utility/Proxyable.sol";
import "./StakingPool.sol";


contract StakingPoolFactory is IStakingPoolFactory, Proxyable {

    uint256 internal version;
    bool internal upgraded = false;

    IStakingPoolFactoryStorage internal factoryStorage;

    constructor(
        address _factoryStorage, // Staking pool factory storage
        address payable _proxy, // Staking pool factory proxy
        address _owner // Staking pool factory owner address
    )
        public
        Proxyable(_proxy, _owner)
    {
        require(_factoryStorage != address(0), "StakingPoolFactory: factory storage is zero address");
        factoryStorage = IStakingPoolFactoryStorage(_factoryStorage);
        version = 1;
    }

    modifier isNotUpgraded() {
        require(!upgraded, "StakingPoolFactory: the factory was upgraded");
        _;
    }

    function deployStakingPool(
        string memory _name,
        address _vault,
        address _lpToken,
        address _owner
    )
    	public
        isNotUpgraded
    	optionalProxy_onlyOwner
    {
        StakingPool stakingPool = StakingPool(
            createStakingPool(
                _name,
                address(this),
                _vault,
                _lpToken,
                _owner
            )
        );

        IOwned(_vault).nominateNewOwner(address(stakingPool));
        IOwned(_lpToken).nominateNewOwner(address(stakingPool));

        stakingPool.acceptOwnership(_vault);
        stakingPool.acceptOwnership(_lpToken);

        factoryStorage.addStakingPool(address(stakingPool));
    }

    function upgradeStakingPool(address payable _pool)
        public
        isNotUpgraded
        optionalProxy_onlyOwner
    {
        require(factoryStorage.removeStakingPool(_pool), "StakingPoolFactory: pool not deleted from factory storage");
        StakingPool oldPool = StakingPool(_pool);
        StakingPool newPool = StakingPool(
            createStakingPool(
                oldPool.name(),
                _pool,
                address(oldPool.getVault()),
                address(oldPool.getLPToken()),
                oldPool.owner()
            )
        );
        oldPool.upgrade(address(newPool));
        require(factoryStorage.addStakingPool(address(newPool)), "StakingPoolFactory: pool not added to factory storage");
    }

    function disableStakingPool(/*address payable _pool*/)
        public
        isNotUpgraded
        optionalProxy_onlyOwner
    {
        this;
    }

    function upgradeFactory(address _facotry)
        public
        isNotUpgraded
        optionalProxy_onlyOwner
    {
        require(_facotry != address(0), "StakingPoolFactory: FACTORY is zero address");
        require(StakingPoolFactory(_facotry).getVersion() > version, "StakingPoolFactory: pool factory version has to be higher");
        IOwned(address(factoryStorage)).nominateNewOwner(_facotry);
        upgraded = true;
    }

    function acceptOwnership(address _addr)
        public
        isNotUpgraded
        optionalProxy_onlyOwner
    {
        IOwned(_addr).acceptOwnership();
    }

    function createStakingPool(
        string memory _name,
        address _oldPool,
        address _vault,
        address _lpToken,
        address _owner
    )
        internal
        returns (address payable)
    {
        return address(
            new StakingPool(
                _name,
                address(proxy),
                _oldPool,
                _vault,
                _lpToken,
                factoryStorage.getOKS(),
                1,
                _owner
            )
        );
    }

    function getVersion() public view returns(uint256) {
        return version;
    }

    function getFactoryStorage() public view returns(address) {
        return address(factoryStorage);
    }

    function getStakingPools() public view returns(address[] memory) {
        return factoryStorage.getStakingPools();
    }
}   