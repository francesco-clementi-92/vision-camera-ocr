// https://github.com/react-native-community/cli/blob/main/docs/dependencies.md

module.exports = {
  dependency: {
    platforms: {
      /**
       * @type {import('@react-native-community/cli-types').IOSDependencyParams}
       */
      ios: {
        podspecPath: './VisionCameraTextRecognition.podspec',
      },
      /**
       * @type {import('@react-native-community/cli-types').AndroidDependencyParams}
       */
      android: {},
    },
  },
}
