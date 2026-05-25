using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARSubsystems;
using UnityEngine.InputSystem;
using FlutterUnityIntegration;


public class TimecapsuleAR : MonoBehaviour
{
    [Header("AR Components")]
    public ARRaycastManager raycastManager;
    public ARPlaneManager planeManager;

    [Header("Capsule")]
    public GameObject capsulePrefab;

    private GameObject _spawnedCapsule;
    private bool _isPlaced = false;
    private bool _isBurying = false;

    private static List<ARRaycastHit> _hits = new List<ARRaycastHit>();

    void Update()
    {
        if (_isPlaced || _isBurying) return;
        if (_spawnedCapsule == null) return;

        // 화면 중앙 기준으로 바닥 히트테스트
        Vector2 screenCenter = new Vector2(Screen.width / 2f, Screen.height / 2f);
        if (raycastManager.Raycast(screenCenter, _hits, TrackableType.PlaneWithinPolygon))
        {
            Pose hitPose = _hits[0].pose;
            _spawnedCapsule.transform.position = hitPose.position + Vector3.up * 0.1f;
            _spawnedCapsule.transform.rotation = hitPose.rotation;
        }
    }

    // Flutter에서 캡슐 소환 호출
    public void SpawnCapsule(string message)
    {
        if (_spawnedCapsule != null)
            Destroy(_spawnedCapsule);

        _isPlaced = false;
        _isBurying = false;

        if (capsulePrefab != null)
            _spawnedCapsule = Instantiate(capsulePrefab);
    }

    // Flutter에서 묻기 호출
    public void BuryCapsule(string message)
    {
        if (_spawnedCapsule == null || _isBurying) return;
        _isPlaced = true;
        _isBurying = true;
        StartCoroutine(BuryAnimation());
    }

    private IEnumerator BuryAnimation()
    {
        Vector3 startPos = _spawnedCapsule.transform.localScale;
        float duration = 1.0f;
        float elapsed = 0f;

        // 떨어지는 애니메이션
        Vector3 fallStart = _spawnedCapsule.transform.position;
        Vector3 fallEnd = fallStart + Vector3.down * 0.1f;
        while (elapsed < duration * 0.4f)
        {
            elapsed += Time.deltaTime;
            float t = elapsed / (duration * 0.4f);
            _spawnedCapsule.transform.position = Vector3.Lerp(fallStart, fallEnd, t);
            yield return null;
        }

        // 땅속으로 들어가는 애니메이션
        elapsed = 0f;
        Vector3 buryStart = _spawnedCapsule.transform.position;
        Vector3 buryEnd = buryStart + Vector3.down * 0.2f;
        Vector3 scaleStart = _spawnedCapsule.transform.localScale;
        Vector3 scaleEnd = Vector3.zero;
        while (elapsed < duration * 0.6f)
        {
            elapsed += Time.deltaTime;
            float t = elapsed / (duration * 0.6f);
            _spawnedCapsule.transform.position = Vector3.Lerp(buryStart, buryEnd, t);
            _spawnedCapsule.transform.localScale = Vector3.Lerp(scaleStart, scaleEnd, t);
            yield return null;
        }

        Destroy(_spawnedCapsule);

        // Flutter에 완료 이벤트 전송
        SendMessageToFlutter("BuryComplete");
    }

    private void SendMessageToFlutter(string message)
    {
        UnityMessageManager.Instance.SendMessageToFlutter(message);
        Debug.Log("Flutter message: " + message);
    }
}
