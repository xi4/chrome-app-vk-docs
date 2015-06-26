angular.module 'utils'
  .factory 'utils',($http)->
    utils =
      GVP:(url,parameterName)->
        urlParameters = url.substr(url.indexOf('#')+1)
        urlParameters = urlParameters.split "&"
        for i in [0...urlParameters.length]
          temp = urlParameters[i].split "="
          parameterValue = temp[1] if temp[0] == parameterName
        return parameterValue
      errorParse:(response)->
        self.auth() if response.error.error_code == 5
        return
      objToStr:(obj)->
        str=''
        angular.forEach(obj,(value,key)->
          str+=key+'='+value+'&'
          return
        )
        return str
      sizeFormat:(bytes)->
        sizes = [
          'Bytes'
          'KB'
          'MB'
          'GB'
          'TB'
        ]
        return '0 Byte' if bytes == 0
        i = parseInt Math.floor(Math.log(bytes) / Math.log(1024))
        return Math.round(bytes / Math.pow(1024, i), 2) + ' ' + sizes[i]
      getImgData:(url)->
        imgData = {}
        utils.getBlob url,(data)->
          imgData = window.URL.createObjectURL(data)
          return
        return imgData
      getUrl:->
        url = aut_url
        url = url.replace('{client_id}', client_id)
        url = url.replace('{scope}', scope)
        url = url.replace('{redirect_uri}', callback_blank)
        url = url.replace('{version}', version)
        return url
      getBlob:(url,callback)->
        $http.get(url,responseType:'blob')
        .success(callback)
        .error (data)->
          console.log(data)
          return
        return
      downloadFile:(file)->
        utils.getBlob file.url,(blob)->
          chrome.storage.local.get 'selDir', (item)->
            chrome.fileSystem.isRestorable item.selDir, (selDir)->
              if selDir
                chrome.fileSystem.restoreEntry item.selDir, (entry)->
                  entry.getFile file.title, {create: true}, (ent)->
                    ent.createWriter (writer)->
                      writer.write blob
                      chrome.fileSystem.getDisplayPath entry, (path)->
                        logs.message file.title, 'Файл успешно сохранент в папку: \n' + path, 'download'
              else
                logs.message 'Ошибка', 'Папка для сохранения файла не выбрана!\nДля выбора папки воспользуйтесь настройками.', 'error'

    return utils
