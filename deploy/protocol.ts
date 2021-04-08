import { DeployFunction } from 'hardhat-deploy/types'
import { deployDiamond } from '../utils/deploy-diamond'

const deployProtocol: DeployFunction = async (hre) => {
  const {} = hre

  await deployDiamond({
    hre,
    name: 'TellerDiamond',
    facets: [
      'LendingFacet',
      'CreateLoanFacet',
      'LoanDataFacet',
      'CollateralFacet',
      'RepayFacet',
      'LiquidateFacet',
      'SignersFacet',
      'StakingFacet',
      'EscrowFacet',
    ],
  })
}

deployProtocol.tags = ['protocol']

export default deployProtocol